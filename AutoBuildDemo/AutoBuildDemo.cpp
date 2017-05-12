// AutoBuildDemo.cpp : 定义控制台应用程序的入口点。
//

#include "stdafx.h"
#include <windows.h>

int main()
{
    int iCount = 0;
    printf("-------------------\r\n");
    while (iCount < 99999)
    {
        printf(" index: %d \r",iCount++);
        Sleep(100);
    }
    return 0;
}

