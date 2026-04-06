#!/usr/bin/env python3
"""
3:4 比例截图工具
用法: python3 screenshot.py
操作: 拖拽选择区域，松手自动截图并复制到剪贴板，ESC 取消
"""
import tkinter as tk
import subprocess

RATIO_W = 3
RATIO_H = 4
BG_FILE = '/tmp/screenshot_bg.png'
OUT_FILE = '/tmp/screenshot_34.png'


def get_screen_info():
    """
    用 Quartz 获取鼠标位置和所在屏幕边界。
    全程不初始化任何 Tk 窗口，避免触发 macOS 焦点切换。
    返回 (sx, sy, sw, sh)。
    """
    try:
        from Quartz import (CGGetActiveDisplayList, CGDisplayBounds,
                             CGEventCreate, CGEventGetLocation)
        event = CGEventCreate(None)
        pos = CGEventGetLocation(event)
        mx, my = pos.x, pos.y

        _, displays, _ = CGGetActiveDisplayList(32, None, None)
        print(f'鼠标: ({int(mx)},{int(my)})，检测到 {len(displays)} 个显示器')
        for i, d in enumerate(displays):
            b = CGDisplayBounds(d)
            print(f'  显示器{i+1}: ({int(b.origin.x)},{int(b.origin.y)}) {int(b.size.width)}×{int(b.size.height)}')
            if (b.origin.x <= mx < b.origin.x + b.size.width and
                    b.origin.y <= my < b.origin.y + b.size.height):
                print(f'  → 使用显示器{i+1}')
                return (int(b.origin.x), int(b.origin.y),
                        int(b.size.width), int(b.size.height))
        b = CGDisplayBounds(displays[0])
        return (int(b.origin.x), int(b.origin.y),
                int(b.size.width), int(b.size.height))
    except ImportError:
        print('Quartz 未安装，使用默认屏幕（需要安装: pip install pyobjc-framework-Quartz）')
        return None


class Selector:
    def __init__(self, sx, sy, sw, sh):
        self.sx, self.sy, self.sw, self.sh = sx, sy, sw, sh
        self.start_x = self.start_y = None
        self.end_x = self.end_y = None
        self.rect_id = self.size_id = None

        self.root = tk.Tk()
        self._setup_window()

    def _setup_window(self):
        self.root.overrideredirect(True)
        self.root.attributes('-topmost', True)
        self.root.geometry(f'{self.sw}x{self.sh}+{self.sx}+{self.sy}')

        self.canvas = tk.Canvas(
            self.root, bg='#111111', cursor='crosshair', highlightthickness=0
        )
        self.canvas.pack(fill='both', expand=True)

        try:
            self.bg_photo = tk.PhotoImage(file=BG_FILE)
            self.canvas.create_image(0, 0, anchor='nw', image=self.bg_photo)
            print(f'背景图已显示: {self.bg_photo.width()}×{self.bg_photo.height()}')
        except Exception as e:
            print(f'背景图加载失败: {e}')

        self.canvas.create_text(
            self.sw // 2, 30,
            text='拖拽选择区域（3:4 比例）  |  ESC 取消',
            fill='white', font=('Arial', 14, 'bold')
        )

        self.canvas.bind('<ButtonPress-1>', self._on_press)
        self.canvas.bind('<B1-Motion>', self._on_drag)
        self.canvas.bind('<ButtonRelease-1>', self._on_release)
        self.root.bind('<Escape>', lambda _: self.root.destroy())
        self.root.lift()
        self.root.focus_force()

    def _constrain(self, dx, dy):
        aw, ah = abs(dx), abs(dy)
        if aw * RATIO_H > ah * RATIO_W:
            aw = ah * RATIO_W / RATIO_H
        else:
            ah = aw * RATIO_H / RATIO_W
        return int(aw * (1 if dx >= 0 else -1)), int(ah * (1 if dy >= 0 else -1))

    def _on_press(self, event):
        self.start_x, self.start_y = event.x, event.y
        self._clear_rect()

    def _on_drag(self, event):
        if self.start_x is None:
            return
        cdx, cdy = self._constrain(event.x - self.start_x, event.y - self.start_y)
        self.end_x = self.start_x + cdx
        self.end_y = self.start_y + cdy
        self._clear_rect()

        x1 = min(self.start_x, self.end_x)
        y1 = min(self.start_y, self.end_y)
        x2 = max(self.start_x, self.end_x)
        y2 = max(self.start_y, self.end_y)

        self.rect_id = self.canvas.create_rectangle(
            x1, y1, x2, y2, outline='#FF3B30', width=2
        )
        self.size_id = self.canvas.create_text(
            (x1 + x2) / 2, (y1 + y2) / 2,
            text=f' {abs(cdx)} × {abs(cdy)} ',
            fill='white', font=('Arial', 13, 'bold')
        )

    def _on_release(self, event):
        if self.end_x is None:
            return
        x1 = min(self.start_x, self.end_x)
        y1 = min(self.start_y, self.end_y)
        x2 = max(self.start_x, self.end_x)
        y2 = max(self.start_y, self.end_y)
        w, h = int(x2 - x1), int(y2 - y1)
        if w < 20 or h < 20:
            return
        gx = int(x1) + self.sx
        gy = int(y1) + self.sy
        print(f'选区全局坐标: ({gx},{gy}) {w}×{h}')
        self.root.withdraw()
        self.root.after(300, lambda: self._capture_and_quit(gx, gy, w, h))

    def _capture_and_quit(self, x, y, w, h):
        subprocess.run(['screencapture', '-R', f'{x},{y},{w},{h}', OUT_FILE], check=True)
        subprocess.run([
            'osascript', '-e',
            f'set the clipboard to (read (POSIX file "{OUT_FILE}") as «class PNGf»)'
        ], check=True)
        print(f'截图完成：{w}×{h}，已复制到剪贴板，文件：{OUT_FILE}')
        self.root.destroy()

    def _clear_rect(self):
        for id_ in (self.rect_id, self.size_id):
            if id_:
                self.canvas.delete(id_)
        self.rect_id = self.size_id = None

    def run(self):
        self.root.mainloop()


if __name__ == '__main__':
    # ① 用 Quartz 获取屏幕信息（不初始化 Tk，避免触发焦点切换）
    screen = get_screen_info()

    if screen is None:
        # 无 Quartz：用 Tk 获取屏幕尺寸（只支持主屏幕）
        tmp = tk.Tk()
        tmp.withdraw()
        screen = (0, 0, tmp.winfo_screenwidth(), tmp.winfo_screenheight())
        tmp.destroy()

    sx, sy, sw, sh = screen
    print(f'使用屏幕: ({sx},{sy}) {sw}×{sh}')

    # ② 截背景图（此时 Tk 还未初始化，屏幕状态干净）
    r1 = subprocess.run(['screencapture', '-x', '-R', f'{sx},{sy},{sw},{sh}', BG_FILE])
    print(f'背景截图: {"成功" if r1.returncode == 0 else "失败"}')

    r2 = subprocess.run(['sips', '-z', str(sh), str(sw), BG_FILE], capture_output=True)
    print(f'sips 缩放: {"成功" if r2.returncode == 0 else "失败"}')

    # ③ 初始化 Tk，展示选区 UI
    Selector(sx, sy, sw, sh).run()
