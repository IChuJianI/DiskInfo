export class DiskListItem {
  node: string = '';
  title: string = '';
  subtitle: string = '';
  health: number = 0;
}

export class InfoEntry {
  label: string = '';
  value: string = '';
}

export class SmartRow {
  id: string = '';
  name: string = '';
  current: string = '';
  worst: string = '';
  threshold: string = '';
  raw: string = '';
  warn: boolean = false;
}
