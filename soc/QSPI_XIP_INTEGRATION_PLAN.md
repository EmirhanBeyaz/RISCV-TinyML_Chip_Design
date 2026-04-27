# QSPI XIP Entegrasyon Plani

Bu dokuman, secilen ucuncu taraf `QSPI XIP` cekirdegini mevcut SoC iskeletimize nasil oturtacagimizi sabitler.

## Seçilen Upstream Dosyalar

Doğrudan vendor edilecek ana RTL:
- `rtl/qflexpress.v`

Referans olarak birlikte tutulacak dosyalar:
- `autodata/qflexpress.txt`
- `sw/flashdrvr.cpp`
- `README.md`

Seçim gerekçesi:
- `README.md` upstream repoda `qflexpress.v` dosyasını Quad SPI flash çekirdeği olarak tanımlıyor.
- `autodata/qflexpress.txt` AutoFPGA entegrasyonunda doğrudan `qflexpress.v` dosyasını RTL dosyası olarak gösteriyor.
- `qflexpress.v` kendi içinde tam flash-read/XIP davranışı ve startup mantığı taşıyor.
- `flashdrvr.cpp`, çekirdeğin ham config komut formatını anlamak için önemli referans.

## Mevcut Yerel Bağlam

Bugün elimizde şu iki yerel blok zaten var:
- [soc_apb_qspi_cfg.sv](./soc_apb_qspi_cfg.sv#L1)
- [soc_boot_copy_xip.sv](./soc_boot_copy_xip.sv#L1)

Ve top-level SoC içinde:
- `SOC_QSPI_CFG_BASE_ADDR` bir APB/MMIO register alanı
- `SOC_QSPI_XIP_BASE_ADDR` bir XIP veri penceresi

Bu ayrım korunacak:
- `QSPI_CFG` = kontrol ve durum düzlemi
- `QSPI_XIP` = flash içeriğini okuma düzlemi

## `qflexpress` Hakkında Kritik Gerçek

`qflexpress` bizim mevcut SoC’mize doğrudan oturmuyor.

Sebep:
- arayüzü `Wishbone` benzeri
- veri portu ve config portu aynı çekirdeğin içinde birleşik
- config işlemleri basit CSR register’lar değil, ham komut kelimeleri

Özellikle `flashdrvr.cpp` içindeki bu bitler bunu açık gösteriyor:
- `CFG_USERMODE = 1 << 12`
- `CFG_QSPEED = 1 << 11`
- `CFG_WEDIR = 1 << 9`
- `CFG_USER_CS_n = 1 << 8`

Bu yüzden `soc_apb_qspi_cfg` ile `qflexpress` arasında doğrudan birebir register eşlemesi yapmak doğru değil.

## Gerekli Wrapper Katmanları

### 1. `soc_qspi_xip.sv`

Bu, `qflexpress` üstünde duran ince RTL wrapper olacak.

Sorumlulukları:
- `qflexpress` instantiate etmek
- parametreleri yerel SoC tarafına uyarlamak
- fiziksel QSPI pinlerini SoC isimlendirmesiyle dışarı çıkarmak
- çekirdeğin `startup/busy/ack` davranışını daha temiz yerel sinyallere çevirmek

Bu modülün ham `qflexpress` detaylarını SoC’nin geri kalanından saklaması gerekiyor.

### 2. `soc_axi_lite_qspi_xip.sv`

Bu, `qflexpress` tabanlı XIP alanını `AXI-Lite` read-only slave gibi gösterecek bus shim olacak.

Sorumlulukları:
- `AXI-Lite AR/R` kanalını kabul etmek
- adresi `qflexpress` içindeki word adresine çevirmek
- `Wishbone` benzeri `cyc/stb/ack/stall/data` akışına dönüştürmek
- write isteklerinde `SLVERR` dönmek

Bu katman gerekli çünkü [soc_boot_copy_xip.sv](./soc_boot_copy_xip.sv#L1) bugün XIP kaynağını `AXI-Lite` okunabilir alan gibi görüyor.

### 3. İleri Faz İçin `qspi_cfg` Köprüsü

İlk fazda zorunlu değil.

Ikinci fazda gerekirse:
- `soc_apb_qspi_cfg` içine komut/arg/doorbell register’ları eklenir
- kucuk bir `soc_qspi_cfg_bridge.sv` modulu ile bu register yazilari `qflexpress` config komut akisina cevrilir

Ama bu kapıyı ilk günden açmak istemiyoruz. İlk hedef `boot-copy` ve `XIP read`.

## `qspi_cfg` Nasıl Bağlanacak

[soc_apb_qspi_cfg.sv](./soc_apb_qspi_cfg.sv#L1) yerinde kalacak. Bu blok şu an için yanlış değil; sadece görev alanı farklı.

Bu blok:
- SoC-visible metadata/status bloğu olacak
- `boot_active`, `boot_done`, `boot_enable`
- `xip_base_addr`
- `imem_base_addr`
- `copy_words`
- scratch register’lar

İlk entegrasyon fazında `qspi_cfg` içine eklenecek yeni okunur alanlar:
- `flash_present`
- `flash_init_done`
- `flash_busy`
- `flash_error`

İlk entegrasyon fazında eklenmeyecekler:
- erase/program komut register’ları
- tam ham config kelimesi sürme arayüzü

Kısacası:
- `qspi_cfg`, kullanıcı dostu SoC register bloğu olarak kalacak
- `qflexpress` içindeki ham komut yolu şimdilik wrapper içinde saklı kalacak

## `boot-copy` Yoluna Nasıl Oturacak

Bugünkü akış:
- [soc_boot_copy_xip.sv](./soc_boot_copy_xip.sv#L1), `SOC_QSPI_XIP_BASE_ADDR` alanından kelime kelime okuma yapıyor
- dönen veriyi `IMEM` içine yazıyor

Hedef akış:
1. `soc_boot_copy_xip` yine `SOC_QSPI_XIP_BASE_ADDR + offset` adreslerine `AXI-Lite` read başlatacak
2. [cv32e40p_axi_soc.sv](./cv32e40p_axi_soc.sv#L1) içinde bu adres aralığı artık dış AXI yerine yerel `qspi_xip` bloğuna decode edilecek
3. `soc_axi_lite_qspi_xip` bu read'i alip `qflexpress` istegine cevirecek
4. `qflexpress` gerçek QSPI flash’tan kelimeyi okuyacak
5. veri tekrar `AXI-Lite R` cevabı olarak `boot-copy` FSM’ine dönecek
6. `boot-copy` bu veriyi `IMEM`e yazacak

Bu sayede `boot-copy` FSM’ini büyük ölçüde değiştirmeden QSPI flash’ı gerçek veri kaynağı yapmış olacağız.

## Top-Level Decode Değişikliği

`SOC_QSPI_XIP_BASE_ADDR` alanı, entegrasyon sonrası dış dünyaya bırakılan “geçici scratch” bölgesi olmaktan çıkacak.

Yeni data-side decode sırası:
1. `DMEM` local
2. `MMIO` local
3. `QSPI_XIP` local
4. `else -> external AXI`

Bu kararın yan etkisi:
- bugün bazı testlerde `SOC_QSPI_XIP_BASE_ADDR` dış scratch alanı gibi kullanılıyor
- gerçek XIP entegrasyonunda bu testlerin yeni bir external scratch adresine taşınması gerekecek

## Parametre Kararları

İlk entegrasyon için önerilen `qflexpress` parametreleri:
- `LGFLASHSZ = 24`
- `OPT_PIPE = 1`
- `OPT_CFG = 1`
- `OPT_STARTUP = 1`
- `OPT_CLKDIV = 1`
- `OPT_ENDIANSWAP = 0`
- `RDDELAY = 1`
- `NDUMMY = 6`

Bunlar `autodata/qflexpress.txt` içindeki örnek entegrasyonla uyumlu başlangıç değerleri.

## Fazlara Bölünmüş Uygulama Sırası

### Faz 1
- upstream dosya seçimini dondur
- vendor manifest ekle
- `soc_qspi_xip.sv` iskeletini ekle

### Faz 2
- `rtl/qflexpress.v` dosyasını vendor et
- `soc_axi_lite_qspi_xip.sv` read-only wrapper'ini yaz
- ayrı birim smoke test ekle

### Faz 3
- `cv32e40p_axi_soc.sv` içine `SOC_QSPI_XIP_BASE_ADDR` local decode ekle
- `soc_boot_copy_xip` testlerini yerel XIP üzerinden tekrar koştur

### Faz 4
- `qspi_cfg` içine init/busy/error görünürlüğü ekle
- istersek daha sonra config komut köprüsüne geç

## İlk Test Hedefleri

Yeni birim testi:
- `tb_soc_axi_lite_qspi_xip.sv`
- read-only XIP pencere davranışı
- write -> `SLVERR`

Yeni sistem testi:
- `tb_cv32e40p_axi_soc_boot_copy_qspi.sv`
- boot-copy FSM gerçekten yerel `QSPI_XIP` alanından okuyor mu
- dış AXI okunmuyor mu
- kopyalanan program `IMEM`den fetch ediliyor mu

## Kritik Dürüst Not

İlk fazda `qspi_cfg` ve `qflexpress` arasında tam erase/program yolu kurmuyoruz.

Bu bilinçli bir karar:
- yarışma mimarisi için önce `boot` ve `read/XIP` değer üretiyor
- ham flash programlama yolu ise daha riskli ve ikinci aşama

Önce doğru olan:
- `XIP read`
- `boot-copy`
- `IMEM execute`

Sonra gelmesi gereken:
- `flash command`
- `erase/program`
- tam firmware-controlled flash management
