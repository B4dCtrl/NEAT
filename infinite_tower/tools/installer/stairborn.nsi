; Stairborn installer for Windows (NSIS 3).
; Installs for the current user only (no administrator prompt) into
; %LOCALAPPDATA%\Programs\Stairborn, adds Start menu and desktop shortcuts and
; an entry in "Apps & features" to uninstall. Saves are never touched.
;
; Build (from infinite_tower/, after exporting export/windows/):
;   makensis -DVERSION=0.9.0 tools/installer/stairborn.nsi
; Output: export/Stairborn-Setup.exe

Unicode true
!include "MUI2.nsh"

!ifndef VERSION
  !define VERSION "0.9.0"
!endif
!define APP "Stairborn"
!define EXE "Stairborn.exe"
!define UNINST_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP}"

Name "${APP}"
OutFile "..\..\export\Stairborn-Setup.exe"
InstallDir "$LOCALAPPDATA\Programs\${APP}"
InstallDirRegKey HKCU "Software\${APP}" "InstallDir"
RequestExecutionLevel user
SetCompressor /SOLID lzma
BrandingText "${APP} ${VERSION}"

VIProductVersion "${VERSION}.0"
VIAddVersionKey "ProductName" "${APP}"
VIAddVersionKey "FileDescription" "${APP} Setup"
VIAddVersionKey "FileVersion" "${VERSION}"
VIAddVersionKey "ProductVersion" "${VERSION}"
VIAddVersionKey "CompanyName" "${APP}"
VIAddVersionKey "LegalCopyright" "${APP}"

!define MUI_ICON "icon.ico"
!define MUI_UNICON "icon.ico"
!define MUI_WELCOMEFINISHPAGE_BITMAP "welcome.bmp"
!define MUI_UNWELCOMEFINISHPAGE_BITMAP "welcome.bmp"
!define MUI_ABORTWARNING
!define MUI_FINISHPAGE_RUN "$INSTDIR\${EXE}"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

; The installer speaks the language of Windows when it is one of these.
!insertmacro MUI_LANGUAGE "PortugueseBR"
!insertmacro MUI_LANGUAGE "Spanish"
!insertmacro MUI_LANGUAGE "English"

LangString DESKTOP_LINK ${LANG_PORTUGUESEBR} "Stairborn"
LangString DESKTOP_LINK ${LANG_SPANISH} "Stairborn"
LangString DESKTOP_LINK ${LANG_ENGLISH} "Stairborn"
LangString TEST_LINK ${LANG_PORTUGUESEBR} "Stairborn (modo teste)"
LangString TEST_LINK ${LANG_SPANISH} "Stairborn (modo de prueba)"
LangString TEST_LINK ${LANG_ENGLISH} "Stairborn (test mode)"
LangString UNINSTALL_LINK ${LANG_PORTUGUESEBR} "Desinstalar Stairborn"
LangString UNINSTALL_LINK ${LANG_SPANISH} "Desinstalar Stairborn"
LangString UNINSTALL_LINK ${LANG_ENGLISH} "Uninstall Stairborn"

Section "Stairborn" SecMain
  SectionIn RO
  ; An open copy of the game would lock its files: close it first (it
  ; saves every few seconds, so at most a moment of progress is lost).
  nsExec::Exec 'taskkill /IM ${EXE} /F'
  Sleep 500
  SetOutPath "$INSTDIR"
  File "..\..\export\windows\Stairborn.exe"
  File "..\..\export\windows\Stairborn.pck"
  File "icon.ico"
  File "THIRD_PARTY_NOTICES.txt"
  WriteUninstaller "$INSTDIR\Uninstall.exe"

  CreateDirectory "$SMPROGRAMS\${APP}"
  CreateShortcut "$SMPROGRAMS\${APP}\$(DESKTOP_LINK).lnk" "$INSTDIR\${EXE}" "" "$INSTDIR\icon.ico" 0
  CreateShortcut "$SMPROGRAMS\${APP}\$(UNINSTALL_LINK).lnk" "$INSTDIR\Uninstall.exe" "" "$INSTDIR\icon.ico" 0
  CreateShortcut "$DESKTOP\$(DESKTOP_LINK).lnk" "$INSTDIR\${EXE}" "" "$INSTDIR\icon.ico" 0
  ; Test mode: its own accounts and saves, and an ADMIN panel (see core/admin.gd).
  CreateShortcut "$SMPROGRAMS\${APP}\$(TEST_LINK).lnk" "$INSTDIR\${EXE}" "-- --admin" "$INSTDIR\icon.ico" 0
  CreateShortcut "$DESKTOP\$(TEST_LINK).lnk" "$INSTDIR\${EXE}" "-- --admin" "$INSTDIR\icon.ico" 0

  WriteRegStr HKCU "Software\${APP}" "InstallDir" "$INSTDIR"
  WriteRegStr HKCU "${UNINST_KEY}" "DisplayName" "${APP}"
  WriteRegStr HKCU "${UNINST_KEY}" "DisplayVersion" "${VERSION}"
  WriteRegStr HKCU "${UNINST_KEY}" "Publisher" "${APP}"
  WriteRegStr HKCU "${UNINST_KEY}" "DisplayIcon" "$INSTDIR\icon.ico"
  WriteRegStr HKCU "${UNINST_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "${UNINST_KEY}" "UninstallString" '"$INSTDIR\Uninstall.exe"'
  WriteRegStr HKCU "${UNINST_KEY}" "QuietUninstallString" '"$INSTDIR\Uninstall.exe" /S'
  WriteRegDWORD HKCU "${UNINST_KEY}" "NoModify" 1
  WriteRegDWORD HKCU "${UNINST_KEY}" "NoRepair" 1
  WriteRegDWORD HKCU "${UNINST_KEY}" "EstimatedSize" 86000
SectionEnd

Section "Uninstall"
  nsExec::Exec 'taskkill /IM ${EXE} /F'
  Sleep 500
  Delete "$INSTDIR\Stairborn.exe"
  Delete "$INSTDIR\Stairborn.pck"
  Delete "$INSTDIR\icon.ico"
  Delete "$INSTDIR\THIRD_PARTY_NOTICES.txt"
  Delete "$INSTDIR\Uninstall.exe"
  RMDir "$INSTDIR"
  Delete "$DESKTOP\$(DESKTOP_LINK).lnk"
  Delete "$DESKTOP\$(TEST_LINK).lnk"
  Delete "$SMPROGRAMS\${APP}\$(TEST_LINK).lnk"
  Delete "$SMPROGRAMS\${APP}\$(DESKTOP_LINK).lnk"
  Delete "$SMPROGRAMS\${APP}\$(UNINSTALL_LINK).lnk"
  RMDir "$SMPROGRAMS\${APP}"
  DeleteRegKey HKCU "${UNINST_KEY}"
  DeleteRegKey HKCU "Software\${APP}"
SectionEnd
