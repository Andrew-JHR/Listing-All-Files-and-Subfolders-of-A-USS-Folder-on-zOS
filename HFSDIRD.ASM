//ANDREWJB JOB  IBM,,CLASS=A,MSGCLASS=X,NOTIFY=&SYSUID
//STEP1    EXEC ASMACLG,PARM.G='/'
//SYSIN    DD   *
**********************************************************************
* Swap Modified Time and Created Time                           C200720
*                                                               C200720
*                          Andrew Jan 2020/07/20                C200720
**********************************************************************
* Increasing path's length Andrew Jan 2019/08/23                C190823
**********************************************************************
* This program is used to display the file status for the entire
* directory. Files and sub-directories are included.
* If the root directory: '/' is specified as the parameter, the entire
* HFS is listed.
* Andrew Jan 26/Apr/2007
**********************************************************************
         PRINT NOGEN
*------------------------------------------------*
*
         PRINT OFF
         LCLA  &REG
.LOOP    ANOP                              GENERATE REGS.
R&REG    EQU   &REG
&REG     SETA  &REG+1
         AIF   (&REG LE 15).LOOP
         PRINT ON
*
         BPXYDIRE ,        dir entry map
         BPXYSTAT ,        the response structure for stat
         BPXYMODE ,        the constants of file services
         BPXYFTYP ,        the file type definitions
*
WORKAREA DSECT  ,
SAVER11  DS    F
SAVER    DS    13F
RETVAL   DS    F
PLIST    DS    6F

RETCODE  DS    F
RSNCODE  DS    F
DIRDESC  DS    F

LINKLVL1 DS    F
LINKLVL2 DS    F
LINKLVL3 DS    F

DIROUTA  DS    F
DIROUTL  DS    F
DIRALET  DS    F
FSTATL   DS    F
PATHNL   DS    F
BUFLENA  DS    F
PATHN    DS    CL512
BUFFERA  DS    CL512
DIROUT   DS    CL2048
FSTAT    DS    CL(STAT#LENGTH)      length of stat

WORKLEN  EQU   *-WORKAREA
*
*------------------------------------------------*
*
HFSDIRD  CSECT
HFSDIRD  AMODE 31
         USING *,R15              setup addressibility
         STM   R14,R12,12(R13)      USE R13 AS BASE AS WELL AS
         LR    R2,R13               REG-SAVE AREA
         STM   R14,R12,12(R13)    save parent's register
         LR    R2,R13             parent's save area pointer
         B     CMNTTAIL           skip over the remarks
*
CMNTHEAD EQU   *
         PRINT GEN                print out remarks
         DC    CL8'&SYSDATE'      compiling date
         DC    C' '
         DC    CL5'&SYSTIME'      compiling time
         DC    C'ANDREW JAN'      author
         CNOP  2,4                ensure half word boundary
         PRINT NOGEN              disable macro expansion
CMNTTAIL EQU   *

         BALR  R12,0
         BAL   R13,76(R12)

         DROP  R15                avoid compiling warning

SAVREG   DS    18F
         USING SAVREG,R13
         ST    R2,4(R13)
         ST    R13,8(R2)
*
*---MAINSTREAM------------------------------------*
*
*
        BAL    R6,GET_PARM          get the argument
*
        BAL    R6,OPEN_FILES        open the output file
*
        BAL    R6,GO_PROCESS        go process
*
FINISH  EQU    *
        BAL    R6,CLOSE_FILES       close the output file
*
        B      RETURN               back
*
*-------------------------------------------------------*
*
GET_PARM   EQU  *
         L     R1,0(,R1)            get parm
         LH    R3,0(,R1)            get parm length
         LTR   R3,R3                any argument specified ?
         BZ    RETURN               no, cease doing any further

         LA    R2,2(,R1)            start of the argument

         ST    R3,ARGULEN           dir name lenth
         BCTR  R3,0                 -1 for ex
EXMVC    MVC   ARGUMNT(0),0(R2)     mask for ex
         EX    R3,EXMVC             print out the value in seconds

         BR    R6

OPEN_FILES EQU  *
         OPEN  (OUTFILE,OUTPUT)
         BR    R6
*
*-------------------------------------------------------*
*
GO_PROCESS  EQU   *

         USING WORKAREA,R11         addressibility
         GETMAIN RC,LV=WORKLEN,BNDRY=PAGE,LOC=ANY
         LR    R11,R1

READ_DIR    EQU   *

         STM   R14,R10,SAVER        save parent's registers
         LR    R2,R11               save parent's workarea addr
         GETMAIN RC,LV=WORKLEN,BNDRY=PAGE,LOC=ANY
         LR    R11,R1
         ST    R2,SAVER11           save parent's r11

         MVC   BUFLENA,ARGULEN      copy len
         L     R3,BUFLENA           save the len
         BCTR  R3,0                 -1 for ex
EXMVC7   MVC   BUFFERA(0),ARGUMNT   copy content
         EX    R3,EXMVC7            do the move

         LA    R2,BUFFERA           1st char of input parm
         AR    R2,R3                point to last char

         CLI   0(R2),C'/'           extra / ?
         BE    READ_DIR_1           yes, go back
         MVI   1(R2),C'/'           put the extra /
         L     R3,BUFLENA           dir name lenth dont count /
         LA    R3,1(,R3)            add 1 for the extra /
         ST    R3,BUFLENA           dir name lenth dont count /

READ_DIR_1  EQU   *
         L     R2,BUFLENA           path name len
         ST    R2,PATHNL            save the path name len
         BCTR  R2,0                 -1 for ex
EXMVC4   MVC   PATHN(0),BUFFERA     mask for ex
         EX    R2,EXMVC4            do the move to save the path name

         CALL  BPX1OPD,                                                X
               (BUFLENA,            dir name length                    X
               BUFFERA,             dir name                           X
               RETVAL,              return value:-1 or dir f.d.        X
               RETCODE,             return code                        X
               RSNCODE),            reason code                        X
               VL,MF=(E,PLIST)
         ICM   R15,B'1111',RETVAL   test return value
         BL    RETURN               error
         ST    R15,DIRDESC          dir descriptor

         LA    R15,DIROUT           output for dir
         ST    R15,DIROUTA          addr of the output for dir
         MVC   DIROUTL,=A(L'DIROUT) output area length
         XR    R1,R1                clear
         ST    R1,DIRALET           init as zero as the default


RD_DIR_LOOP    EQU  *

         CALL  BPX1RDD,                                                X
               (DIRDESC,            dir descriptor                     X
               DIROUTA,             addr of the output                 X
               DIRALET,             buffer alet                        X
               DIROUTL,             size                               X
               RETVAL,              return value:-1 or dir f.d.        X
               RETCODE,             return code                        X
               RSNCODE),            reason code                        X
               VL,MF=(E,PLIST)

         L     R9,RETVAL            load how many entries this read?
         LTR   R9,R9                test if reaching the end
         BNP   RD_DIR_END           yes, branch

         BAL   R7,LST_DIR_ENT       list the dir entry

         B     RD_DIR_LOOP          branch if there are entries left

RD_DIR_END   EQU *
         CALL  BPX1CLD,                                                X
               (DIRDESC,            dir descriptor                     X
               RETVAL,              return value:-1 or dir f.d.        X
               RETCODE,             return code                        X
               RSNCODE),            reason code                        X
               VL,MF=(E,PLIST)

         L     R2,SAVER11           store back
         FREEMAIN RC,LV=WORKLEN,A=(R11)
         LR    R11,R2               parent's workarea is back
         LM    R14,R10,SAVER        save parent's registers

         BR    R6
*
*-------------------------------------------------*
*
LST_DIR_ENT EQU *
         USING DIRE,R4
         LA    R4,DIROUT            addressibility

LOOP_DIR_ENTRY EQU *

         LH    R3,DIRENTNAML        entry name len.

         LTR   R3,R3                chk if zero
         BZ    LST_DIR_ENT_END      yes, branch

         L     R2,PATHNL            the path name len.
         AR    R2,R3                total path name len.
         ST    R2,BUFLENA           save the len. for getting stat
         BCTR  R2,0                 -1 for ex
EXMVC5   MVC   BUFFERA(0),PATHN     mask for ex
         EX    R2,EXMVC5            do the move
         LA    R5,BUFFERA           1st addr
         A     R5,PATHNL            start addr for entry name

         BCTR  R3,0                 -1 for ex
EXMVC2   MVC   0(0,R5),DIRENTNAME   mask for moving entry name
         EX    R3,EXMVC2            do the move

         ST    R7,LINKLVL1          save r7
         BAL   R7,READ_FILE_STAT    call the subroutine
         L     R7,LINKLVL1          retore r7

         LH    R3,DIRENTLEN         entry len.
         AR    R4,R3                alter base address
         BCT   R9,LOOP_DIR_ENTRY    loop thru all entries for this read

LST_DIR_ENT_END EQU  *
         BR    R7
*
*-------------------------------------------------*
*
READ_FILE_STAT EQU *
         MVC   FSTATL,=A(STAT#LENGTH)
         CALL  BPX1LST,             get file status                    X
               (BUFLENA,            pathname len. (in)                 X
               BUFFERA,             pathname (in)                      X
               FSTATL,              buffer len                         X
               FSTAT,               buffer                             X
               RETVAL,              return value:-1 or dir f.d.        X
               RETCODE,             return code                        X
               RSNCODE),            reason code                        X
               VL,MF=(E,PLIST)

WKSIZE   EQU   400                                              C190823
         MVI   WORK,C' '             clear output area
&MX      SETA  WKSIZE                                           C190823
&BS      SETA  0                                                C190823
&BN      SETA  1                                                C190823
.LP1     ANOP  ,                                                C190823
         AIF   (&MX GE 256).LP2                                 C190823
&WK      SETC  'WORK+'.'&BN'.'('.'&MX'.'),WORK+'.'&BS'          C190823
         MVC   &WK                                              C190823
         AGO   .LP3                                             C190823
.LP2     ANOP  ,                                                C190823
&WK      SETC  'WORK+'.'&BN'.'(256),WORK+'.'&BS'                C190823
         MVC   &WK                                              C190823
&MX      SETA  &MX-256                                          C190823
&BS      SETA  &BS+256                                          C190823
&BN      SETA  &BS+1                                            C190823
         AGO   .LP1                                             C190823
.LP3     ANOP  ,                                                C190823

         MVI   WKNAME+L'WKNAME,C','
         MVI   WKMTIME+L'WKMTIME,C','
         MVI   WKFSIZE+L'WKFSIZE,C','
         MVI   WKCRTIME+L'WKCRTIME,C','
         MVI   WKOWNER+L'WKOWNER,C','
         MVI   WKFTYPE+L'WKFTYPE,C','
         MVI   WKFVER+L'WKFVER,C','

S        USING STAT,FSTAT            for file stat
M        USING S_MODE,S.ST_MODE      for file mode

         CLI   M.S_TYPE,FT_DIR       is it directory ?   1
         BNZ   CHK_FT1
         MVI   WKFTYPE,C'd'
         B     CHK_OK
CHK_FT1  EQU   *
         CLI   M.S_TYPE,FT_REGFILE   regular file ?  3
         BNZ   CHK_FT2
         MVI   WKFTYPE,C'f'
         B     CHK_OK
CHK_FT2  EQU   *
         CLI   M.S_TYPE,FT_SYMLINK   regular file ?  5
         BNZ   CHK_FT3
         MVI   WKFTYPE,C'l'
         B     CHK_OK
CHK_FT3  EQU   *
         CLI   M.S_TYPE,FT_CHARSPEC  char. special file  2
         BNZ   CHK_FT4
         MVI   WKFTYPE,C'c'
         B     CHK_OK
CHK_FT4  EQU   *
         CLI   M.S_TYPE,FT_FIFO     fifo pipe           4
         BNZ   CHK_FT5
         MVI   WKFTYPE,C'p'
         B     CHK_OK
CHK_FT5  EQU   *
         CLI   M.S_TYPE,FT_SOCKET   socket file         7
         BNZ   CHK_FT6
         MVI   WKFTYPE,C's'
         B     CHK_OK
CHK_FT6  EQU   *
         MVI   WKFTYPE,C'o'         others
CHK_OK   EQU   *

* chk r,w,x for owner group and other
         MVI   WK_1,X'F0'           init.
         TM    M.S_MODE2,S_IRUSR    chk owner's read auth.
         BNO   CHK_OWN1             no, branch
         OI    WK_1,X'04'           read auth
CHK_OWN1 EQU   *
         TM    M.S_MODE3,S_IWUSR    chk owner's write auth.
         BNO   CHK_OWN2             no, branch
         OI    WK_1,X'02'           write auth
CHK_OWN2 EQU   *
         TM    M.S_MODE3,S_IXUSR    chk owner's exec auth.
         BNO   CHK_OWN3             no, branch
         OI    WK_1,X'01'           exec auth
CHK_OWN3 EQU   *
         MVC   WKFTYPE+1(1),WK_1    owner's auth

         MVI   WK_1,X'F0'           init.
         TM    M.S_MODE3,S_IRGRP    chk group's read auth.
         BNO   CHK_GRP1             no, branch
         OI    WK_1,X'04'           read auth
CHK_GRP1 EQU   *
         TM    M.S_MODE3,S_IWGRP    chk group's write auth.
         BNO   CHK_GRP2             no, branch
         OI    WK_1,X'02'           write auth
CHK_GRP2 EQU   *
         TM    M.S_MODE3,S_IXGRP    chk group's exec auth.
         BNO   CHK_GRP3             no, branch
         OI    WK_1,X'01'           exec auth
CHK_GRP3 EQU   *
         MVC   WKFTYPE+2(1),WK_1    group's auth

         MVI   WK_1,X'F0'           init.
         TM    M.S_MODE3,S_IROTH    chk other's read auth.
         BNO   CHK_OTH1             no, branch
         OI    WK_1,X'04'           read auth
CHK_OTH1 EQU   *
         TM    M.S_MODE3,S_IWOTH    chk other's write auth.
         BNO   CHK_OTH2             no, branch
         OI    WK_1,X'02'           write auth
CHK_OTH2 EQU   *
         TM    M.S_MODE3,S_IXOTH    chk other's exec auth.
         BNO   CHK_OTH3             no, branch
         OI    WK_1,X'01'           exec auth
CHK_OTH3 EQU   *
         MVC   WKFTYPE+3(1),WK_1    group's auth

* check visible
         UNPK  WK_8(3),S.ST_VISIBLE(2)
         TR    WK_8(2),X2C-C'0'
         MVC   WKFTYPE+4(2),WK_8    apf etc. information

* ST_SHARELIB   x'10'  shared library
* ST_NOSHAREAS  x'08'  not shared
* ST_APFAUTH    x'04'  apf authorized
* ST_PROGCTL    x'02'  program controlled
* ST_EXTLINK    x'01'  external symbolic link

* get the modify time
         LGF   R3,S.ST_MTIME        load the access time
         ST    R7,LINKLVL2          save register
         BAL   R7,UTCCONV
         L     R7,LINKLVL2          restore register
         MVC   WKMTIME,WK_17        print the time

* get the file size
         UNPK  WK_8(9),S.ST_SIZE_L(5) left full word
         TR    WK_8,X2C-C'0'        readable
         MVC   WKFSIZE,WK_8+2       print the file size

* uid
         UNPK  WK_8(9),S.ST_UID(5)  uid
         TR    WK_8,X2C-C'0'        readable
         MVC   WKOWNER,WK_8         print the file size

* gid
         UNPK  WK_8(9),S.ST_GID(5)  uid
         TR    WK_8,X2C-C'0'        readable
         MVC   WKFVER,WK_8          print the file size

* creation time
         LGF   R3,S.ST_CREATETIME   file creation time
         ST    R7,LINKLVL2          save register
         BAL   R7,UTCCONV
         L     R7,LINKLVL2          restore register
         MVC   WKCRTIME,WK_17       print the time

* path name
         L     R3,BUFLENA           entry name len.
         LTR   R3,R3                chk if a valid entry
         BZ    READ_STAT_END        bypass this

         BCTR  R3,0                 -1 for ex
EXMVC3   MVC   WKPATH(0),BUFFERA    path  name
         EX    R3,EXMVC3            really move
         LA    R3,WKPATH            1st char
         A     R3,BUFLENA           next char of last char of path
         MVI   0(R3),C','           delimiter

* entry name (first 8 bytes)
         CLI   M.S_TYPE,FT_DIR      dir entry?
         BE    READ_STAT_PRT        no, branch
         LH    R3,DIRENTNAML        entry name len
         CH    R3,=H'8'             more than 8 bytes?
         BNH   READ_STAT_NAME       no,branch
         LH    R3,=H'8'             more than 8 bytes?
READ_STAT_NAME EQU *
         BCTR  R3,0                 -1 for ex
EXMVC6   MVC   WKNAME(0),DIRENTNAME entry name
         EX    R3,EXMVC6            really move

READ_STAT_PRT  EQU *
         PUT   OUTFILE,WORK         print result

*--recursively call read_dir------------------------*
         CLI   M.S_TYPE,FT_DIR      dir entry?
         BNE   READ_STAT_END        no, branch

         L     R3,BUFLENA           load len.
         LA    R2,BUFFERA           starting addr
         AR    R2,R3                the byte next to the last byte
         BCTR  R2,0                 -1 to get the last byte
         CLI   0(R2),C'.'           virtual dir entry
         BE    READ_STAT_END        yes, branch

         MVC   ARGULEN,BUFLENA      save the path name len
         L     R3,ARGULEN           load the path name len
         BCTR  R3,0                 -1 for ex
EXMVC8   MVC   ARGUMNT(0),BUFFERA   mask for ex
         EX    R3,EXMVC8            save the path name

         BAL   R6,READ_DIR          recursive call
*---------------------------------------------------*

READ_STAT_END  EQU *
         BR    R7                   go back

*-------------------------------------------------*

UTCCONV  EQU   *
         MLG   R2,TOD_1SEC          convert utc into tod
         AG    R3,TOD_1970          add the starting of utc
         AG    R3,TOD_GMT           convert into local time
         STG   R3,WRK_D             convert into local time
         STCKCONV STCKVAL=WRK_D,CONVVAL=WK_16,DATETYPE=YYYYMMDD,       X
               MF=(E,STCKCONL)

         UNPK  WK_8(9),P_Y4MMDD(5)         unpack the decimal value
         MVC   WK_17(8),WK_8               move yyyymmdd
         MVI   WK_17+8,C','                delimiter
         UNPK  WK_8(7),P_HHMMSS(4)         unpack the decimal value
         MVC   WK_17+9(2),WK_8             move hh
         MVI   WK_17+11,C':'               delimiter
         MVC   WK_17+12(2),WK_8+2          move mm
         MVI   WK_17+14,C':'               delimiter
         MVC   WK_17+15(2),WK_8+4          move ss

         BR    R7                          return

*
*--------------------------------------------------------*
*
CLOSE_FILES EQU  *
         CLOSE  OUTFILE           CLOSE FILES
         BR    R6
*
*--------------------------------------------------------*
*
RETURN   EQU   *
         L     R13,4(R13)
         ST    R15,16(,R13)        save the return code
         LM    R14,R12,12(R13)     restore registers
         L     R14,12(,R13)        load return address
         BR    R14                 go back to caller
*
*--------------------------------------------------------*
*
         LTORG

WRK_D    DS    D

TOD_1970 DS   0D
         DC   X'7D91048BCA000000'  tod for Jan 1st 1970 midnight
TOD_GMT  DS   0D
         DC   X'00006B49D2000000'  tod value for 8 hours
TOD_1SEC DC   0D
         DC   X'00000000F4240000'  tod for 1 second

ARGULEN  DS    F
ARGUMNT  DS    CL512

WORK     DS    CL(WKSIZE)
         ORG   WORK
WKNAME   DS    CL8
         DS    C
WKCRTIME DS    CL17                                             C200720
         DS    C
WKFSIZE  DS    CL6
         DS    C
WKMTIME  DS    CL8                                              C200720
         DS    C
WKOWNER  DS    CL8
         DS    C
WKFTYPE  DS    CL6
         DS    C
WKFVER   DS    CL8
         DS    C
WKPATH   DS    CL(WKSIZE-*+WKNAME)                              C190823
         ORG

WK_16    DS    0CL16          fullword boundary
P_HHMMSS DS    CL3            packed hhmmss
P_TH     DS    CL3            packed thijuu0000
         DS    CL2            reserved
P_Y4MMDD DS    CL4            packed yyyy
         DS    CL4            reserved
         ORG   P_Y4MMDD
P_Y4DDD  DS    CL4
         ORG   P_Y4MMDD
P_Y2K    DS    CL1
P_YYDDD  DS    CL3
         ORG
WK_8     DS    CL8
WK_1     DS    CL1
WK_17    DS    CL17

STCKCONL STCKCONV MF=L

X2C      DC    C'0123456789ABCDEF'
*
*--------------------------------------------------------*
*
OUTFILE  DCB DSORG=PS,DDNAME=SYSPRINT,MACRF=PM                  C190823
*
*
         END
/*
//*
//L.SYSLIB   DD  DISP=SHR,DSN=SYS1.CSSLIB
//*.SYSPRINT DD  SYSOUT=*
//G.SYSPRINT DD  DISP=SHR,DSN=SYS1.ZOS.D240910.OMVS
//
//
//
//
//* The Following statements are used if the most recently updated
//* files are to be listed first
//*.SYSPRINT DD  DSN=&&TEMP,DCB=(RECFM=FB,LRECL=400,BLKSIZE=27824),
//*   SPACE=(CYL,(50,50)),UNIT=SYSDA,DISP=(NEW,PASS)
//*
//SORT     EXEC PGM=SORT,REGION=4096K
//SORTIN   DD DISP=(OLD,DELETE),DSN=&&TEMP
//SORTWK1  DD UNIT=SYSDA,SPACE=(CYL,(20,9))
//SORTWK2  DD UNIT=SYSDA,SPACE=(CYL,(20,9))
//SYSPRINT DD SYSOUT=*
//SYSOUT   DD SYSOUT=*
//SORTOUT  DD DISP=SHR,DSN=SYS1.ZOS.D240910.OMVS
//SYSIN    DD *
 SORT  FIELDS=(10,8,CH,D,19,8,CH,D,1,8,CH,A,69,44,CH,A)
 END
/*
//
