const { contextBridge, ipcRenderer } = require("electron");

contextBridge.exposeInMainWorld("seorinDesktop", {
  isDesktopApp: true,
  platform: process.platform,
  getAppVersion() {
    return ipcRenderer.invoke("seorin-get-app-version");
  },
  checkForUpdates() {
    return ipcRenderer.invoke("seorin-check-for-updates");
  },
  downloadUpdate() {
    return ipcRenderer.invoke("seorin-download-update");
  },
  installUpdate() {
    return ipcRenderer.invoke("seorin-install-update");
  },
  onUpdateStatus(callback) {
    if (typeof callback !== "function") return () => {};
    const handler = (_event, payload) => callback(payload || {});
    ipcRenderer.on("seorin-update-status", handler);
    return () => ipcRenderer.removeListener("seorin-update-status", handler);
  },
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
