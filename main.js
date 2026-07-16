const { app, BrowserWindow, shell, session, dialog, ipcMain, Notification, nativeImage } = require("electron");
const { autoUpdater } = require("electron-updater");
const path = require("path");

let mainWindow;
let updateCheckTimer;
let updateDownloaded = false;
let updateBusy = false;
let availableVersion = null;
let taskbarAttentionActive = false;

function createRedAttentionIcon() {
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32">
    <circle cx="16" cy="16" r="13" fill="#ef233c" stroke="#ffffff" stroke-width="4"/>
  </svg>`;
  return nativeImage.createFromDataURL(`data:image/svg+xml;base64,${Buffer.from(svg).toString("base64")}`).resize({ width: 16, height: 16 });
}

function setTaskbarAttention(active = true) {
  taskbarAttentionActive = Boolean(active);
  if (!mainWindow || mainWindow.isDestroyed() || process.platform !== "win32") return;
  try {
    mainWindow.setOverlayIcon(taskbarAttentionActive ? createRedAttentionIcon() : null, taskbarAttentionActive ? "새 대화 또는 변경 알림" : "");
    mainWindow.flashFrame(taskbarAttentionActive);
  } catch (error) {
    console.error("작업표시줄 알림 표시 실패:", error);
  }
}

function restoreAndFocusMainWindow() {
  if (!mainWindow || mainWindow.isDestroyed()) return;
  if (mainWindow.isMinimized()) mainWindow.restore();
  if (!mainWindow.isVisible()) mainWindow.show();
  mainWindow.focus();
}

ipcMain.on("seorin-show-desktop-notification", (_event, payload = {}) => {
  setTaskbarAttention(true);
  try {
    if (!Notification.isSupported()) return;
    const notification = new Notification({
      title: String(payload.title || "서린컴퍼니 새 알림"),
      body: String(payload.body || "새로운 내용이 등록되었습니다."),
      icon: path.join(__dirname, "build", "icon.png"),
      timeoutType: "never",
      urgency: "normal"
    });
    notification.on("click", () => {
      setTaskbarAttention(false);
      restoreAndFocusMainWindow();
      mainWindow.webContents.send("seorin-desktop-notification-click", payload);
    });
    notification.show();
  } catch (error) {
    console.error("Windows 알림 표시 실패:", error);
  }
});


ipcMain.on("seorin-set-taskbar-attention", (_event, active = true) => {
  setTaskbarAttention(active);
});

ipcMain.handle("seorin-clear-taskbar-attention", () => {
  setTaskbarAttention(false);
  return { ok: true };
});

function sendUpdateStatus(status, detail = {}) {
  if (!mainWindow || mainWindow.isDestroyed()) return;
  mainWindow.webContents.send("seorin-update-status", {
    status,
    currentVersion: app.getVersion(),
    availableVersion,
    ...detail
  });
}

async function checkForUpdates(manual = false) {
  if (!app.isPackaged) {
    sendUpdateStatus("dev-mode", { message: "개발 실행에서는 업데이트를 확인하지 않습니다." });
    return;
  }
  if (updateBusy) {
    sendUpdateStatus("busy", { message: "업데이트 작업이 진행 중입니다." });
    return;
  }
  updateBusy = true;
  sendUpdateStatus("checking", { manual });
  try {
    await autoUpdater.checkForUpdates();
  } catch (error) {
    console.error("업데이트 확인 실패:", error);
    sendUpdateStatus("error", { message: error?.message || "업데이트 확인에 실패했습니다." });
    updateBusy = false;
  }
}

ipcMain.handle("seorin-get-app-version", () => app.getVersion());
ipcMain.handle("seorin-check-for-updates", async () => {
  await checkForUpdates(true);
  return { ok: true };
});
ipcMain.handle("seorin-download-update", async () => {
  if (!app.isPackaged) return { ok: false, message: "개발 실행에서는 다운로드할 수 없습니다." };
  try {
    updateBusy = true;
    sendUpdateStatus("downloading", { percent: 0 });
    await autoUpdater.downloadUpdate();
    return { ok: true };
  } catch (error) {
    updateBusy = false;
    sendUpdateStatus("error", { message: error?.message || "업데이트 다운로드에 실패했습니다." });
    return { ok: false, message: error?.message || "업데이트 다운로드 실패" };
  }
});
ipcMain.handle("seorin-install-update", () => {
  if (!updateDownloaded) return { ok: false, message: "설치할 업데이트가 아직 준비되지 않았습니다." };
  setImmediate(() => autoUpdater.quitAndInstall(false, true));
  return { ok: true };
});

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1500,
    height: 930,
    minWidth: 1050,
    minHeight: 700,
    show: false,
    title: "서린컴퍼니 물류포털",
    icon: path.join(__dirname, "build", "icon.ico"),
    backgroundColor: "#f4f7fb",
    autoHideMenuBar: true,
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
      webSecurity: true
    }
  });

  mainWindow.loadFile(path.join(__dirname, "app", "index.html"));

  mainWindow.once("ready-to-show", () => {
    mainWindow.maximize();
    mainWindow.show();
  });

  mainWindow.on("focus", () => {
    if (taskbarAttentionActive) setTaskbarAttention(false);
  });

  mainWindow.webContents.setWindowOpenHandler(({ url }) => {
    if (/^https?:/i.test(url)) shell.openExternal(url);
    return { action: "deny" };
  });

  mainWindow.webContents.on("will-navigate", (event, url) => {
    const local = `file://${path.join(__dirname, "app")}`.replace(/\\/g, "/");
    if (!url.startsWith(local) && /^https?:/i.test(url)) {
      event.preventDefault();
      shell.openExternal(url);
    }
  });
}

function setupAutoUpdate() {
  if (!app.isPackaged) {
    sendUpdateStatus("dev-mode", { message: "개발 실행 중" });
    return;
  }

  autoUpdater.autoDownload = false;
  autoUpdater.autoInstallOnAppQuit = true;
  autoUpdater.allowPrerelease = false;

  autoUpdater.on("checking-for-update", () => {
    sendUpdateStatus("checking");
  });

  autoUpdater.on("update-available", async (info) => {
    availableVersion = info.version;
    updateBusy = false;
    sendUpdateStatus("available", { version: info.version });

    if (Notification.isSupported()) {
      const notification = new Notification({
        title: "서린컴퍼니 물류포털 업데이트",
        body: `새 버전 ${info.version}이 있습니다. 클릭하면 다운로드를 시작합니다.`,
        icon: path.join(__dirname, "build", "icon.png")
      });
      notification.on("click", async () => {
        restoreAndFocusMainWindow();
        try {
          updateBusy = true;
          sendUpdateStatus("downloading", { percent: 0 });
          await autoUpdater.downloadUpdate();
        } catch (error) {
          updateBusy = false;
          sendUpdateStatus("error", { message: error?.message || "업데이트 다운로드 실패" });
        }
      });
      notification.show();
    }
  });

  autoUpdater.on("update-not-available", () => {
    availableVersion = null;
    updateBusy = false;
    sendUpdateStatus("not-available", { message: "현재 최신 버전입니다." });
  });

  autoUpdater.on("download-progress", (progress) => {
    sendUpdateStatus("downloading", {
      percent: Math.max(0, Math.min(100, Math.round(progress.percent || 0))),
      transferred: progress.transferred,
      total: progress.total,
      bytesPerSecond: progress.bytesPerSecond
    });
  });

  autoUpdater.on("error", (error) => {
    console.error("자동 업데이트 오류:", error);
    updateBusy = false;
    sendUpdateStatus("error", { message: error?.message || "자동 업데이트 오류" });
  });

  autoUpdater.on("update-downloaded", async (info) => {
    updateDownloaded = true;
    updateBusy = false;
    availableVersion = info.version;
    sendUpdateStatus("downloaded", { version: info.version });

    const result = await dialog.showMessageBox(mainWindow, {
      type: "info",
      title: "업데이트 준비 완료",
      message: `새 버전 ${info.version} 다운로드가 완료되었습니다.`,
      detail: "지금 재시작하면 자동으로 새 버전이 설치됩니다.",
      buttons: ["재시작 후 설치", "나중에"],
      defaultId: 0,
      cancelId: 1,
      noLink: true
    });

    if (result.response === 0) {
      autoUpdater.quitAndInstall(false, true);
    }
  });

  setTimeout(() => checkForUpdates(false), 7000);
  updateCheckTimer = setInterval(() => checkForUpdates(false), 4 * 60 * 60 * 1000);
}

app.whenReady().then(() => {
  session.defaultSession.setPermissionRequestHandler((_wc, permission, callback) => {
    callback(["notifications", "clipboard-read"].includes(permission));
  });

  createWindow();
  setupAutoUpdate();

  app.on("activate", () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on("before-quit", () => {
  if (updateCheckTimer) clearInterval(updateCheckTimer);
});

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") app.quit();
});
