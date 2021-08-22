#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

/**
 *
 * ./ledAPP <filename> <0:1> 0关 1开
 */
int main(int argc, char *argv[])
{
    int fd = 0;
    int ret = 0;
    char writebuff[1];
    size_t count = 0;

    if (argc != 3)
    {
        printf("Error usage!\r\n");
        return -1;
    }
    char *filename = argv[1];

    fd = open(filename, O_RDWR);
    if (fd < 0)
    {
        printf("Can't open %s!\r\n", filename);
    }

    /*write*/
    writebuff[0] = atoi(argv[2]);
    ret = write(fd, writebuff, sizeof(writebuff));
    if (ret < 0)
    {
        printf("write file %s failed!\r\n", filename);
    }
    else
    {
        ;
    }

    ret = close(fd);
    if (ret < 0)
    {
        printf("close file * failed!\r\n", filename);
    }
    else
    {
    }

    return 0;
}