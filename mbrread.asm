; Program: MBR Read. Version 1.
; Program for reading boot sector and save its in file.
; Using: mbrread [A|B|0..9] mbrfile.ext
; A|B - floppy disk letter
; 0..9 - hard disk number
; 0 - current (boot) disk

; Errorlevel: 0 - Ok, 1 - Bad command line, 2 - Error read sector from disk,
; 3 - Error saving file

; Copyright 2004 Artyomov Alexander aralni[no spam]mail.ru

; GNU license

; For compilation uses NASM assembler

[ORG 100h]

		mov ah, [80h] ; PSP 80h - length of command line include space
		              ; 80h - boot hdd
		              ; <A|B|0..9> drive number, ,c:\x
		cmp ah, 4     ; space, then drive number, space, filename
		jb near error_paramstr
		cmp ah, 126   ; no above
		ja near error_paramstr

		mov al, ah
		xor ah, ah    ; mov ah, 0
		mov bp, ax
		add bp, 81h   ; command line begin
		mov [bp], ah  ; make ASCIIZ file name

		mov ah, [82h] ; drive number char

		cmp ah, 'A'
		jne metka_as
		mov byte [current_drive], 0
		jmp start
metka_as:
		cmp ah, 'a'
		jne metka_b
		mov byte [current_drive], 0
		jmp start
metka_b:
		cmp ah, 'B'
		jne metka_bs
		mov byte [current_drive], 1
		jmp start
metka_bs:
		cmp ah, 'b'
		jne metka_0
		mov byte [current_drive], 1
		jmp start

metka_0:
		cmp ah, '0'
		jb error_paramstr
		cmp ah, '9'
		ja error_paramstr
		sub ah, '0'
		mov [current_drive], ah
		or  byte [current_drive], 80h

start:		mov ah, 02h ; BIOS service 'read sector(s)'
		mov al, 1   ; count of sectors for read
		mov dl,     [current_drive]
		mov dh, 0   ; head
		mov ch, 0   ; cyl
		mov cl, 1   ; sector
		mov bx,     buffer
		int 13h     ; run service
		mov al, 2   ; exit code 'error read sector'
		jc  exit    ; if error then exit

		mov ah, 3Ch ; DOS service 'create file'
		mov cx, 0   ; attribute of file
		mov dx, 84h    ; file name
		int 21h     ; run service (in AX handle of file)
		mov bx, ax  ; [file_handle]
		mov al, 3   ; exit code 'error write in file'
		jc  exit    ; if error then exit

		mov ah, 40h ; DOS service 'write file'
		mov cx, 512 ; bytes for write
		mov dx,     buffer
		int 21h     ; run service
		mov al, 3   ; exit code 'error write in file'
		jc  exit    ; if error then exit

		mov ah, 3Eh ; DOS service 'close file'
		int 21h     ; run service

		mov al, 0   ; exit code 'All Ok !'

exit:		mov ah, 4Ch
		int 21h

error_paramstr: 
		mov ah, 9   ; DOS 'write string'
		mov dx, msg_using
		int 21h

		mov al, 1   ; error in parametrs
		jmp exit

current_drive   db 0h       ; 80h current hdd. >= 80h hdds. >= 0 < 80 fdds.

msg_using	db 'Using: mbrread [1space] [A|B|0..9] [1space] [mbrfile.bin]',13,10
		db '                       drive number           file name',13,10
		db 'Drive number 0 is current (boot) hard drive, A and B - floppy',13,10
		db 'Errorlevel: 0-Ok, 1-Err Cmd Line, 2-Err Read MBR, 3-Err Save in file',13,10
		db '(c) 2004 Artyomov Alexander. Version 1. GNU License.','$'

buffer: