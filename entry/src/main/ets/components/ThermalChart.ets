@Component
export struct ThermalChart {
  @Prop @Watch('onPointsChanged') points: number[];
  @Prop @Watch('onPointsChanged') useCelsius: boolean;
  private contextSettings: RenderingContextSettings = new RenderingContextSettings(true);
  private canvas: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.contextSettings);
  private widthVp: number = 0;
  private readonly heightVp: number = 150;

  private onPointsChanged(): void {
    this.draw();
  }

  private display(value: number): number {
    if (this.useCelsius) {
      return Math.round(value);
    }
    return Math.round(value * 9 / 5 + 32);
  }

  private minValue(): number {
    if (this.points.length === 0) {
      return 0;
    }
    let min = this.points[0];
    for (const value of this.points) {
      if (value < min) {
        min = value;
      }
    }
    return min;
  }

  private maxValue(): number {
    if (this.points.length === 0) {
      return 0;
    }
    let max = this.points[0];
    for (const value of this.points) {
      if (value > max) {
        max = value;
      }
    }
    return max;
  }

  private draw(): void {
    const width = this.widthVp;
    const height = this.heightVp;
    this.canvas.clearRect(0, 0, width, height);
    if (width <= 0) {
      return;
    }
    const top = 14;
    const bottom = height - 14;
    this.canvas.strokeStyle = 'rgba(128,128,128,0.22)';
    this.canvas.lineWidth = 1;
    for (let i = 0; i <= 3; i++) {
      const y = top + (bottom - top) * i / 3;
      this.canvas.beginPath();
      this.canvas.moveTo(0, y);
      this.canvas.lineTo(width, y);
      this.canvas.stroke();
    }
    if (this.points.length < 2) {
      this.canvas.fillStyle = 'rgba(128,128,128,0.9)';
      this.canvas.font = '12vp sans-serif';
      this.canvas.fillText('---', 8, top + 4);
      return;
    }
    let min = this.points[0];
    let max = this.points[0];
    for (const value of this.points) {
      if (value < min) {
        min = value;
      }
      if (value > max) {
        max = value;
      }
    }
    if (max - min < 4) {
      max = min + 4;
    }
    const span = max - min;
    const stepX = width / (this.points.length - 1);

    this.canvas.strokeStyle = '#0A59F7';
    this.canvas.lineWidth = 2;
    this.canvas.beginPath();
    for (let i = 0; i < this.points.length; i++) {
      const x = i * stepX;
      const y = bottom - (this.points[i] - min) / span * (bottom - top);
      if (i === 0) {
        this.canvas.moveTo(x, y);
      } else {
        this.canvas.lineTo(x, y);
      }
    }
    this.canvas.stroke();

    const last = this.points.length - 1;
    const lastX = last * stepX;
    const lastY = bottom - (this.points[last] - min) / span * (bottom - top);
    this.canvas.fillStyle = '#0A59F7';
    this.canvas.beginPath();
    this.canvas.arc(lastX, lastY, 3, 0, Math.PI * 2);
    this.canvas.fill();

    this.canvas.fillStyle = 'rgba(128,128,128,0.9)';
    this.canvas.font = '11vp sans-serif';
    this.canvas.fillText(this.display(max).toString(), 6, top + 4);
    this.canvas.fillText(this.display(min).toString(), 6, bottom - 2);
  }

  build() {
    Column({ space: 10 }) {
      Row({ space: 12 }) {
        Text($r('app.string.chart_title'))
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        Row({ space: 4 }) {
          Text($r('app.string.chart_min'))
            .fontSize(11)
            .fontColor($r('app.color.text_tertiary'))
          Text(this.display(this.minValue()).toString() + (this.useCelsius ? '°C' : '°F'))
            .fontSize(11)
            .fontColor($r('app.color.text_tertiary'))
        }
        Row({ space: 4 }) {
          Text($r('app.string.chart_max'))
            .fontSize(11)
            .fontColor($r('app.color.text_tertiary'))
          Text(this.display(this.maxValue()).toString() + (this.useCelsius ? '°C' : '°F'))
            .fontSize(11)
            .fontColor($r('app.color.text_tertiary'))
        }
      }
      .width('100%')

      Canvas(this.canvas)
        .width('100%')
        .height(this.heightVp)
        .onReady(() => {
          this.draw();
        })
        .onAreaChange((oldArea: Area, newArea: Area) => {
          const width = parseFloat(newArea.width.toString());
          if (width > 0) {
            this.widthVp = width;
            this.draw();
          }
        })
    }
    .width('100%')
    .padding(18)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(16)
    .alignItems(HorizontalAlign.Start)
  }
}
