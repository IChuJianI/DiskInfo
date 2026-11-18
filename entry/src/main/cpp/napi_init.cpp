#include "napi/native_api.h"

#include <string>
#include <vector>

#include "core/cdi_interpret.h"
#include "core/cdi_json.h"

namespace {

bool GetBuffer(napi_env env, napi_value value, const uint8_t** data,
               size_t* length) {
  *data = nullptr;
  *length = 0;
  bool isArrayBuffer = false;
  if (napi_is_arraybuffer(env, value, &isArrayBuffer) == napi_ok &&
      isArrayBuffer) {
    void* raw = nullptr;
    size_t size = 0;
    if (napi_get_arraybuffer_info(env, value, &raw, &size) != napi_ok) {
      return false;
    }
    *data = static_cast<const uint8_t*>(raw);
    *length = size;
    return true;
  }

  bool isTypedArray = false;
  if (napi_is_typedarray(env, value, &isTypedArray) == napi_ok && isTypedArray) {
    napi_typedarray_type type;
    size_t size = 0;
    void* raw = nullptr;
    napi_value arrayBuffer = nullptr;
    size_t offset = 0;
    if (napi_get_typedarray_info(env, value, &type, &size, &raw, &arrayBuffer,
                                 &offset) != napi_ok) {
      return false;
    }
    *data = static_cast<const uint8_t*>(raw);
    *length = size;
    return true;
  }
  return false;
}

double GetNumber(napi_env env, napi_value value, double fallback) {
  napi_valuetype type = napi_undefined;
  if (napi_typeof(env, value, &type) != napi_ok || type != napi_number) {
    return fallback;
  }
  double number = fallback;
  if (napi_get_value_double(env, value, &number) != napi_ok) {
    return fallback;
  }
  return number;
}

napi_value MakeString(napi_env env, const std::string& text) {
  napi_value result = nullptr;
  napi_create_string_utf8(env, text.c_str(), text.size(), &result);
  return result;
}

napi_value InterpretAta(napi_env env, napi_callback_info info) {
  size_t argc = 7;
  napi_value args[7] = {nullptr};
  napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

  const uint8_t* identify = nullptr;
  size_t identifyLen = 0;
  const uint8_t* smart = nullptr;
  size_t smartLen = 0;
  const uint8_t* threshold = nullptr;
  size_t thresholdLen = 0;
  if (argc < 3 || !GetBuffer(env, args[0], &identify, &identifyLen) ||
      !GetBuffer(env, args[1], &smart, &smartLen)) {
    return MakeString(env, "{\"error\":\"invalid buffers\"}");
  }
  GetBuffer(env, args[2], &threshold, &thresholdLen);

  cdi::InterpretOptions options;
  options.threshold05 = static_cast<uint16_t>(GetNumber(env, args[3], 1));
  options.thresholdC5 = static_cast<uint16_t>(GetNumber(env, args[4], 1));
  options.thresholdC6 = static_cast<uint16_t>(GetNumber(env, args[5], 1));
  options.thresholdFF = static_cast<uint16_t>(GetNumber(env, args[6], 10));

  cdi::DiskInfo disk;
  cdi::ParseAtaIdentify(identify, identifyLen, disk);
  cdi::FillAtaSmart(disk, smart, smartLen, threshold, thresholdLen, options);
  disk.note = "ATA passthrough";
  return MakeString(env, cdi::DiskToJson(disk));
}

napi_value Version(napi_env env, napi_callback_info) {
  return MakeString(env, "9.9.4-harmony.36");
}

napi_value Init(napi_env env, napi_value exports) {
  napi_property_descriptor desc[] = {
      {"interpretAta", nullptr, InterpretAta, nullptr, nullptr, nullptr,
       napi_default, nullptr},
      {"version", nullptr, Version, nullptr, nullptr, nullptr, napi_default,
       nullptr},
  };
  napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
  return exports;
}

}  // namespace

static napi_module diskinfoModule = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = "diskinfo",
    .nm_priv = nullptr,
    .reserved = {0},
};

extern "C" __attribute__((constructor)) void RegisterDiskinfoModule(void) {
  napi_module_register(&diskinfoModule);
}
