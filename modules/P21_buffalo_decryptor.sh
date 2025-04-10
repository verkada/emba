#!/bin/bash -p

# EMBA - EMBEDDED LINUX ANALYZER
#
# Copyright 2020-2024 Siemens Energy AG
#
# EMBA comes with ABSOLUTELY NO WARRANTY. This is free software, and you are
# welcome to redistribute it under the terms of the GNU General Public License.
# See LICENSE file for usage of this software.
#
# EMBA is licensed under GPLv3
#
# Author(s): Michael Messner

# Description: Extracts encrypted firmware images from the vendor Buffalo
#              See https://modemizer.wordpress.com/2015/08/05/restoring-the-original-buffalo-firmware-on-the-wbmr-hp-g300h/
# Pre-checker threading mode - if set to 1, these modules will run in threaded mode
export PRE_THREAD_ENA=0

P21_buffalo_decryptor() {
  local NEG_LOG=0

  if [[ "${BUFFALO_ENC_DETECTED}" -ne 0 ]]; then
    module_log_init "${FUNCNAME[0]}"
    module_title "Buffalo encrypted firmware extractor"
    pre_module_reporter "${FUNCNAME[0]}"

    EXTRACTION_FILE="${LOG_DIR}"/firmware/firmware_buffalo_dec.bin

    buffalo_enc_extractor "${FIRMWARE_PATH}" "${EXTRACTION_FILE}"

    NEG_LOG=1
    module_end_log "${FUNCNAME[0]}" "${NEG_LOG}"
  fi
}

buffalo_enc_extractor() {
  local BUFFALO_ENC_PATH_="${1:-}"
  local EXTRACTION_FILE_="${2:-}"
  local BUFFALO_FILE_CHECK=""

  if ! [[ -f "${BUFFALO_ENC_PATH_}" ]]; then
    print_output "[-] No file for decryption provided"
    return
  fi

  sub_module_title "Buffalo encrypted firmware extractor"

  hexdump -C "${BUFFALO_ENC_PATH_}" | head | tee -a "${LOG_FILE}" || true
  print_ln

  local BUFFALO_DECRYTED=0
  local BUFFALO_ENC_PATH_STRIPPED=""
  BUFFALO_ENC_PATH_STRIPPED="${LOG_DIR}/firmware/$(basename "${BUFFALO_ENC_PATH_}").stripped"

  print_output "[*] Removing initial 208 bytes from header to prepare firmware for decryption"
  # on other tests we had 208 -> check again with firmware that failed here:
  dd bs=208 skip=1 if="${BUFFALO_ENC_PATH_}" of="${BUFFALO_ENC_PATH_STRIPPED}""_208" || true

  if [[ -f "${BUFFALO_ENC_PATH_STRIPPED}""_208" ]]; then
    hexdump -C "${BUFFALO_ENC_PATH_STRIPPED}""_208" | head | tee -a "${LOG_FILE}" || true
    print_ln
  fi

  print_output "[*] Removing initial 228 bytes from header to prepare firmware for decryption"
  dd bs=228 skip=1 if="${BUFFALO_ENC_PATH_}" of="${BUFFALO_ENC_PATH_STRIPPED}""_228" || true

  if [[ -f "${BUFFALO_ENC_PATH_STRIPPED}""_228" ]]; then
    hexdump -C "${BUFFALO_ENC_PATH_STRIPPED}""_228" | head | tee -a "${LOG_FILE}" || true
    print_ln
  fi

  print_output "[*] Decrypting firmware ... offset 208"
  "${EXT_DIR}"/buffalo-enc.elf -d -i "${BUFFALO_ENC_PATH_STRIPPED}""_208" -o "${EXTRACTION_FILE_}" || true
  if ! [[ -f "${EXTRACTION_FILE_}" ]]; then
    print_output "[*] Decrypting firmware ... offset 228"
    "${EXT_DIR}"/buffalo-enc.elf -d -i "${BUFFALO_ENC_PATH_STRIPPED}""_228" -o "${EXTRACTION_FILE_}" || true
  fi
  hexdump -C "${EXTRACTION_FILE_}" | head | tee -a "${LOG_FILE}" || true
  print_ln

  if [[ -f "${EXTRACTION_FILE_}" ]]; then
    BUFFALO_FILE_CHECK=$(file "${EXTRACTION_FILE_}")
    if [[ "${BUFFALO_FILE_CHECK}" =~ .*u-boot\ legacy\ uImage,\ .* ]]; then
      print_ln
      print_output "[+] Decrypted Buffalo firmware file to ${ORANGE}${EXTRACTION_FILE_}${NC}"
      export FIRMWARE_PATH="${EXTRACTION_FILE_}"
      backup_var "FIRMWARE_PATH" "${FIRMWARE_PATH}"
      print_ln
      print_output "[*] Firmware file details: ${ORANGE}$(file "${EXTRACTION_FILE_}")${NC}"
      write_csv_log "Extractor module" "Original file" "extracted file/dir" "file counter" "directory counter" "further details"
      write_csv_log "Buffalo decryptor" "${BUFFALO_ENC_PATH_}" "${EXTRACTION_FILE_}" "1" "NA" "NA"
      BUFFALO_DECRYTED=1
      if [[ -z "${FW_VENDOR:-}" ]]; then
        export FW_VENDOR="BUFFALO"
      fi
    fi
  fi

  if [[ "${BUFFALO_DECRYTED}" -ne 1 ]]; then
    print_output "[-] Decryption of Buffalo firmware file failed"
  fi
}

