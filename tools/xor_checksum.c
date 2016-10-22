/*
**
** Calculate XOR checksum over a file.
** 
** Copyright (c) 2016 Michael Roland <mi.roland@gmail.com>
** 
** This program is free software: you can redistribute it and/or modify
** it under the terms of the GNU General Public License as published by
** the Free Software Foundation, either version 3 of the License, or
** (at your option) any later version.
** 
** This program is distributed in the hope that it will be useful,
** but WITHOUT ANY WARRANTY; without even the implied warranty of
** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
** GNU General Public License for more details.
** 
** You should have received a copy of the GNU General Public License
** along with this program.  If not, see <http://www.gnu.org/licenses/>.
** 
*/

#include <fcntl.h>
#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <libgen.h>
#include <errno.h>


#define DEFAULT_WORD_SIZE 4


void usage(char * programName) {
    printf("Usage: %s file-name [word-size [offset [length]] \n", programName);
    printf("Calculate XOR checksum over a file\n");
    printf("\n");
    printf("Parameters:\n");
    printf("  <file-name>\n");
    printf("  \tInput file\n");
    printf("  <word-size>\n");
    printf("  \tThe size (in bytes) of the XOR checksum value (valid\n");
    printf("  \trange: 1..8), e.g. <word-size> 4 means that the checksum\n");
    printf("  \tconsists of 4 bytes and the input file is processed in\n");
    printf("  \tblocks of 4 bytes (default: %d)\n", DEFAULT_WORD_SIZE);
    printf("  <offset>\n");
    printf("  \tThe offset (in bytes) of the first byte to be included in\n");
    printf("  \tthe checksum calculation (default: 0)\n");
    printf("  <length>\n");
    printf("  \tThe length (in bytes) of the section to be included in the\n");
    printf("  \tchecksum calculation (default: size of input file - offset)\n");
    printf("\n");
    printf("Result:\n");
    printf("  The XOR checksum is output on STDOUT as unsigned integer\n");
    printf("  (checksum bytes interpreted in little endian)\n");
    printf("\n");
    printf("\n");
    printf("Copyright (c) 2016 Michael Roland <mi.roland@gmail.com>\n");
    printf("License GPLv3+: GNU GPL version 3 or later <http://www.gnu.org/licenses/>\n");
    printf("\n");
    printf("This is free software: you can redistribute and/or modify it under\n");
    printf("the terms of the GNU GPLv3+. There is NO WARRANTY; not even the\n");
    printf("implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.\n");
    printf("\n");
}

int main(int argc, char * argv[]) {
    char * programName = basename(argv[0]);
    
    if (argc < 2) {
        fprintf(stderr, "%s: missing argument -- file-name\n", programName);
        usage(programName);
        return 1;
    }
    
    size_t wordSize = 4;
    size_t fileOffset = 0;
    size_t fileLength = 0;
    int hasFileLength = 0;
    char * ptr;
    if (argc > 2) {
        wordSize = strtoull(argv[2], &ptr, 10);
        if ((wordSize < 1) || (wordSize > 8)) {
            fprintf(stderr, "%s: incorrect argument -- word-size %zu out of bounds\n", programName, wordSize);
            usage(programName);
            return 1;
        }
    }
    if (argc > 3) {
        fileOffset = strtoull(argv[3], &ptr, 10);
    }
    if (argc > 4) {
        fileLength = strtoull(argv[4], &ptr, 10);
        hasFileLength = 1;
    }
    //fprintf(stderr, "word-size = %zu\n", wordSize);
    //fprintf(stderr, "offset = %zu\n", fileOffset);
    //fprintf(stderr, "length = %zu\n", fileLength);
    
    int fd = open(argv[1], O_RDONLY);
    int errnum = errno;
    if (fd == -1) {
        fprintf(stderr, "%s: can't open '%s' -- %s (0x%08x)\n", programName, argv[1], strerror(errnum), errnum);
        printf("0\n");
        return 1;
    }
    
    lseek(fd, fileOffset, SEEK_SET);

    uint64_t checksum = 0;
    size_t wordPosition = 0;
    size_t totalBytesRead = 0;
    ssize_t bytesRead = 0;
    size_t const BUFFER_SIZE = 0x01000;
    uint8_t buffer[BUFFER_SIZE];

    do {
        bytesRead = BUFFER_SIZE;
        if ((hasFileLength != 0) && ((fileLength - totalBytesRead) < bytesRead)) {
            bytesRead = fileLength - totalBytesRead;
        }
        bytesRead = read(fd, &buffer[0], bytesRead);
        errnum = errno;
        if (bytesRead > 0) {
            for (size_t i = 0; i < bytesRead; ++i) {
                checksum ^= ((uint64_t)buffer[i] & 0x0ffULL) << (8 * wordPosition++);
                if (wordPosition >= wordSize) {
                    wordPosition = 0;
                }
            }
            totalBytesRead += bytesRead;
        }
    } while (bytesRead > 0);
    
    //fprintf(stderr, "total bytes read = %zu\n", totalBytesRead);

    close(fd);

    if (bytesRead < 0) {
        fprintf(stderr, "%s: read failed (file '%s') -- %s (0x%08x)\n", programName, argv[1], strerror(errnum), errnum);
        printf("0\n");
        return 1;
    }
    
    printf("%" PRIu64 "\n", checksum);
    return 0;
}
