#include "Game.h"
#include <iostream>

#ifdef _WIN32
#include <windows.h>

LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
    switch (msg)
    {
    case WM_DESTROY:
        PostQuitMessage(0);
        return 0;
    case WM_KEYDOWN:
        if (wParam == VK_ESCAPE)
        {
            PostQuitMessage(0);
        }
        return 0;
    }
    return DefWindowProc(hwnd, msg, wParam, lParam);
}

HWND CreateGameWindow(HINSTANCE hInstance, int width, int height)
{
    WNDCLASSEXA wc = { 0 };
    wc.cbSize = sizeof(WNDCLASSEXA);
    wc.style = CS_HREDRAW | CS_VREDRAW;
    wc.lpfnWndProc = WndProc;
    wc.hInstance = hInstance;
    wc.hCursor = LoadCursor(NULL, IDC_ARROW);
    wc.lpszClassName = "DungeonStompDX12Class";
    RegisterClassExA(&wc);

    RECT r = { 0, 0, width, height };
    AdjustWindowRect(&r, WS_OVERLAPPEDWINDOW, FALSE);

    HWND hwnd = CreateWindowExA(0, "DungeonStompDX12Class", "Dungeon Stomp - Microsoft DirectX 12 Ultimate",
        WS_OVERLAPPEDWINDOW, CW_USEDEFAULT, CW_USEDEFAULT,
        r.right - r.left, r.bottom - r.top, NULL, NULL, hInstance, NULL);

    ShowWindow(hwnd, SW_SHOW);
    UpdateWindow(hwnd);
    return hwnd;
}
#endif

int main(int argc, char* argv[])
{
    HWND hwnd = (HWND)0;
#ifdef _WIN32
    HINSTANCE hInstance = GetModuleHandle(NULL);
    hwnd = CreateGameWindow(hInstance, 1280, 720);
#endif

    DungeonStomp::Game game;
    if (game.Initialize(hwnd, 1280, 720))
    {
        std::cout << "[Main] Dungeon Stomp DirectX 12 Ultimate Game Initialized." << std::endl;

#ifdef _WIN32
        MSG msg = { 0 };
        while (msg.message != WM_QUIT && game.IsRunning())
        {
            if (PeekMessage(&msg, NULL, 0, 0, PM_REMOVE))
            {
                TranslateMessage(&msg);
                DispatchMessage(&msg);
            }
            else
            {
                game.Update(0.016f);
                game.Render();
            }
        }
#else
        for (int frame = 0; frame < 100; ++frame)
        {
            game.Update(0.016f);
            game.Render();
        }
#endif
        std::cout << "[Main] Exiting game loop." << std::endl;
        game.Shutdown();
    }
    return 0;
}
