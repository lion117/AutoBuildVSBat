// AutoBuildDemo.cpp : �������̨Ӧ�ó������ڵ㡣
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

