const nodeDetails = {
  core: {
    status: "Hazır",
    title: "CV32E40P",
    body:
      "Ana RISC-V işlemci çekirdeği. Instruction ve data tarafında doğal OBI arayüzleriyle çıkar; SoC içinde bu yollar yerel bellek, MMIO ve QSPI pencerelerine yönlendirilir.",
    items: [
      "Instruction fetch yolu IMEM/ROM/QSPI akışına bağlandı.",
      "Data yolu OBI → AXI-Lite köprüsüyle çevre birimlerine erişiyor.",
      "AI entegrasyonu için adres pencereleri hazır bırakıldı."
    ]
  },
  bridge: {
    status: "Doğrulandı",
    title: "OBI → AXI-Lite Köprüsü",
    body:
      "CV32E40P çekirdeğinin doğal OBI veri erişimleri, SoC içinde AXI-Lite transaction akışına çevrilir. Bu nokta jüri geri bildiriminde özellikle beklenen bağlantıdır.",
    items: [
      "Core üzerindeki OBI arayüzleri mimaride açık gösteriliyor.",
      "Data erişimleri AXI-Lite slave bloklarına yönleniyor.",
      "Instruction yolu yerel IMEM ve external fetch seçeneklerini koruyor."
    ]
  },
  fabric: {
    status: "Hazır",
    title: "AXI-Lite Fabric",
    body:
      "Adres decode sırası tasarımın omurgasıdır: önce yerel bellekler, sonra MMIO, sonra QSPI XIP ve dış AXI yolu ele alınır.",
    items: [
      "DMEM artık yerel bellek olarak çözülüyor.",
      "UART, APB island ve QSPI XIP ayrı slave pencerelerine bağlı.",
      "Basit, no-burst, kolay doğrulanabilir AXI-Lite yolu kullanılıyor."
    ]
  },
  qspi: {
    status: "Entegre",
    title: "QSPI XIP",
    body:
      "Flash içeriği bellek gibi okunabilir bir pencereye taşındı. Boot-copy bloğu bu pencereden uygulama image verisini alıp IMEM’e aktarabiliyor.",
    items: [
      "QSPI XIP base: 0x3000_0000.",
      "Boot image / header okuma yolu test edildi.",
      "Gerçek board flash bring-up, kart geldiğinde yapılacak son fiziksel adımdır."
    ]
  },
  memory: {
    status: "BRAM’e oturdu",
    title: "ROM / IMEM / DMEM",
    body:
      "Bu fazda tüm yerel bellekler single-port, 32-bit, synchronous-read wrapper deseniyle tutuldu. FPGA tarafında inferred BRAM kullanımı oluştu.",
    items: [
      "ROM: 4 KB boot başlangıç alanı.",
      "IMEM: 8 KB yürütülebilir yerel bellek.",
      "DMEM: 8 KB data belleği, dış AXI yerine yerelde çözülüyor."
    ]
  },
  apb: {
    status: "Bağlı",
    title: "APB Island",
    body:
      "GPIO, Timer, I2C ve QSPI_CFG gibi düşük bant genişlikli çevre birimleri AXI-Lite üzerinden APB adasına taşınıyor.",
    items: [
      "Peripheral isimleri tek başına bırakılmadı; bus konumu net.",
      "GPIO ve Timer CORE-V MCU kökenli APB bloklarıyla sarıldı.",
      "QSPI_CFG, flash kontrol yolunun register tarafını temsil ediyor."
    ]
  },
  uart: {
    status: "Bağlı",
    title: "UART0 / UART1",
    body:
      "UART blokları AXI-Lite çevre birimi olarak SoC’ye bağlandı. UART1, ileride AI tarafının haberleşme/debug kanalı olarak da değerlendirilebilir.",
    items: [
      "TX/RX alt blokları wrapper arkasında toplanıyor.",
      "MMIO slotları bellek haritasında ayrılmış durumda.",
      "Testbench ile register erişimleri doğrulandı."
    ]
  },
  fpga: {
    status: "Implementation geçti",
    title: "fpga_top",
    body:
      "Board yokken en kritik temizlik burasıydı: iç SoC sinyalleri top-level IO olmaktan çıkarıldı, dış AXI scratch RAM ile sonlandırıldı ve FPGA-benzeri pin sayısına inildi.",
    items: [
      "IOB kullanımı 30 pine indirildi.",
      "Vivado synthesis ve implementation başarılı.",
      "Gerçek XDC ve kart pinleri board geldiğinde eklenecek."
    ]
  },
  ai: {
    status: "Sonraki faz",
    title: "AI Unit",
    body:
      "AI kısmı bilinçli olarak bu baseline’dan sonra eklenecek. Bunun avantajı, hızlandırıcıyı çalışan bir SoC omurgasına takmak ve hataları ayırabilmek.",
    items: [
      "AI_CSR: kontrol/status register alanı.",
      "AI_MEM: 30 KB hedef veri belleği, 32 KB decode penceresi.",
      "AI_IRQ: hızlandırıcı tamamlandı/hata sinyali için interrupt hattı."
    ]
  }
};

const nodes = document.querySelectorAll(".arch-node");
const title = document.querySelector("#node-title");
const status = document.querySelector("#node-status");
const body = document.querySelector("#node-body");
const list = document.querySelector("#node-list");

function renderNodeDetail(nodeKey) {
  const detail = nodeDetails[nodeKey];
  if (!detail) return;

  nodes.forEach((node) => {
    node.classList.toggle("is-active", node.dataset.node === nodeKey);
  });

  title.textContent = detail.title;
  status.textContent = detail.status;
  status.classList.toggle("muted", nodeKey === "ai");
  status.classList.toggle("success", nodeKey !== "ai");
  body.textContent = detail.body;
  list.replaceChildren(
    ...detail.items.map((item) => {
      const li = document.createElement("li");
      li.textContent = item;
      return li;
    })
  );
}

nodes.forEach((node) => {
  node.addEventListener("click", () => renderNodeDetail(node.dataset.node));
  node.addEventListener("keydown", (event) => {
    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault();
      renderNodeDetail(node.dataset.node);
    }
  });
});
