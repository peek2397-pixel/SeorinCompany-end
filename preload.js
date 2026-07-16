const { contextBridge, ipcRenderer } = require("electron");

contextBridge.exposeInMainWorld("seorinDesktop", {
  isDesktopApp: true,
  platform: process.platform,
  version: "1.0.0",
  showNotification(payload) {
    ipcRenderer.send("seorin-show-desktop-notification", payload || {});
  },
  onNotificationClick(callback) {
    if (typeof callback !== "function") return () => {};
    const handler = (_event, payload) => callback(payload || {});
    ipcRenderer.on("seorin-desktop-notification-click", handler);
    return () => ipcRenderer.removeListener("seorin-desktop-notification-click", handler);
  }
});
