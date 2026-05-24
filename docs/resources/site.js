const mobileMenu = document.querySelector(".mob-menu");
const mobileToggle = document.querySelector(".mob-menu-toggle");

if (mobileMenu && mobileToggle) {
  mobileToggle.addEventListener("click", () => {
    const isOpen = mobileMenu.classList.toggle("menu-open");
    mobileToggle.setAttribute("aria-expanded", String(isOpen));
  });
}

document.querySelectorAll("[data-copy-target]").forEach((button) => {
  button.addEventListener("click", async () => {
    const target = document.getElementById(button.dataset.copyTarget);
    const status = button.parentElement.querySelector(".copy-status");

    if (!target) {
      return;
    }

    const text = target.textContent.trim();

    try {
      await navigator.clipboard.writeText(text);
      if (status) {
        status.textContent = "Copied.";
      }
    } catch {
      const range = document.createRange();
      range.selectNodeContents(target);
      const selection = window.getSelection();
      selection.removeAllRanges();
      selection.addRange(range);
      if (status) {
        status.textContent = "Selected. Press Ctrl+C to copy.";
      }
    }
  });
});

document.querySelectorAll("[data-filter-list]").forEach((input) => {
  const list = document.getElementById(input.dataset.filterList);

  if (!list) {
    return;
  }

  input.addEventListener("input", () => {
    const filter = input.value.trim().toUpperCase();

    list.querySelectorAll("li").forEach((item) => {
      const text = item.textContent.toUpperCase();
      item.style.display = text.includes(filter) ? "" : "none";
    });
  });
});
