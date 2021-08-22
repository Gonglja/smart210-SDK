#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

/**
 *
 * ./chrdevbaseAPP <filename> <1:2> 1读 2写
 */
int main(int argc, char *argv[])
{
	int fd = 0;
	int ret = 0;
	char readbuff[100], writebuff[100];
	static char userdata[] = {"User data."};
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

	if (atoi(argv[2]) == 1)
	{ /*read */
		ret = read(fd, readbuff, 50);
		if (ret < 0)
		{
			printf("read file %s failed!\r\n", filename);
		}
		else
		{
			printf("APP read data:%s\r\n", readbuff);
		}
	}
	else if (atoi(argv[2]) == 2)
	{ /*write*/
		memcpy(writebuff, userdata, sizeof(userdata));
		ret = write(fd, writebuff, 50);
		if (ret < 0)
		{
			printf("write file %s failed!\r\n", filename);
		}
		else
		{
			;
		}
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