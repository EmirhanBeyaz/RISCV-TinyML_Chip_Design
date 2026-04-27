# CD-Rom SoC Demo Dashboard

Bu klasör, FPGA kartı elde yokken jüriye / danışmanlara gösterilebilir statik SoC demo panelini içerir.

## Açma

Tarayıcıdan doğrudan aç:

```bash
xdg-open demo/index.html
```

Alternatif olarak dosyayı Vivado/IDE dışında herhangi bir tarayıcıya sürükleyip bırakmak yeterlidir.

## Ne Anlatıyor?

- `CV32E40P` tabanlı SoC mimari omurgası
- `OBI -> AXI-Lite` dönüşümü
- `ROM / IMEM / DMEM` yerel bellekleri
- `UART / GPIO / Timer / I2C / QSPI_CFG` çevre birimleri
- `QSPI_XIP` boot-copy yolu
- `fpga_top` ile başarılı Vivado synthesis / implementation checkpoint'i
- `AI` tarafının neden sonraki faz olarak ayrıldığı

Bu panel RTL'in yerine geçmez; sunum ve anlaşılabilirlik katmanıdır. Teknik kanıtların kaynağı yine `soc/` altındaki testbenchler, Vivado raporları ve checkpoint dokümanlarıdır.
