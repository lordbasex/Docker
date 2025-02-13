#!/usr/bin/env bash
set -Eeuo pipefail

# Docker environment variables

: "${DEBUG:="no"}"           # Debug mode (yes/no)
: "${KVM:="Y"}"
: "${CPU_PIN:=""}"
: "${CPU_FLAGS:=""}"
: "${CPU_MODEL:=""}"
: "${DEF_MODEL_ARM64:="neoverse-n1"}"    # Default model for ARM64
: "${DEF_MODEL_AMD64:="qemu64"}"         # Default model for AMD64
: "${MACHINE:=""}"                        # Machine type

# Set machine type based on architecture
if [[ "${ARCH,,}" == "amd64" ]]; then
    MACHINE="pc-q35-7.2"          # Standard machine for AMD64
    DEF_MODEL="$DEF_MODEL_AMD64"  # CPU model for AMD64
else
    MACHINE="virt"                # Machine for ARM64
    DEF_MODEL="$DEF_MODEL_ARM64"  # CPU model for ARM64
fi

if [[ "$CPU" == "Cortex A53" ]] && [[ "$CORES" == "6" ]]; then
  # Pin to performance cores on Rockchip Orange Pi 4
  [ -z "$CPU_PIN" ] && CPU_PIN="4,5"
fi

if [[ "$CPU" == "Cortex A55" ]] && [[ "$CORES" == "8" ]]; then
  # Pin to performance cores on Rockchip Orange Pi 5
  [ -z "$CPU_PIN" ] && CPU_PIN="4,5,6,7"
fi

if [[ "$CPU" == "Rockchip RK3588"* ]] && [[ "$CORES" == "8" ]]; then
  # Pin to performance cores on Rockchip Orange Pi 5 Plus
  [ -z "$CPU_PIN" ] && CPU_PIN="4,5,6,7"
fi

# Verify KVM compatibility based on architecture
if [[ "${ARCH,,}" == "amd64" ]]; then
    if [[ "$OSTYPE" =~ ^darwin ]]; then
        KVM="N"
        warn "macOS does not support KVM, this may cause performance loss."
    fi
else
    KVM="N"
    warn "Architecture ${ARCH^^} cannot provide KVM acceleration on this system, this may cause performance loss."
fi

if [[ "$KVM" != [Nn]* ]]; then

  KVM_ERR=""

  if [ ! -e /dev/kvm ]; then
    KVM_ERR="(device file missing)"
  else
    if ! sh -c 'echo -n > /dev/kvm' &> /dev/null; then
      KVM_ERR="(no write access)"
    fi
  fi

  if [ -n "$KVM_ERR" ]; then
    KVM="N"
    if [[ "$OSTYPE" =~ ^darwin ]]; then
      warn "you are using macOS which has no KVM support, this will cause a major loss of performance."
    else
      error "KVM acceleration not available $KVM_ERR, this will cause a major loss of performance."
      error "See the FAQ on how to diagnose the cause, or continue without KVM by setting KVM=N (not recommended)."
      [[ "$DEBUG" != [Yy1]* ]] && exit 88
    fi
  fi

fi

if [[ "$KVM" != [Nn]* ]]; then

  CPU_FEATURES=""
  KVM_OPTS=",accel=kvm -enable-kvm"

  if [ -z "$CPU_MODEL" ]; then
    CPU_MODEL="host"
  fi

else

  CPU_FEATURES=""
  KVM_OPTS=" -accel tcg,thread=multi"

  if [ -z "$CPU_MODEL" ]; then
    if [[ "${ARCH,,}" == "arm64" ]]; then
      CPU_MODEL="max,pauth-impdef=on"
    else
      CPU_MODEL="$DEF_MODEL"
    fi
  fi

  if [[ "${BOOT_MODE,,}" == "windows" ]]; then
    MACHINE+=",virtualization=on"
  fi

fi

if [ -z "$CPU_FLAGS" ]; then
  if [ -z "$CPU_FEATURES" ]; then
    CPU_FLAGS="$CPU_MODEL"
  else
    CPU_FLAGS="$CPU_MODEL,$CPU_FEATURES"
  fi
else
  if [ -z "$CPU_FEATURES" ]; then
    CPU_FLAGS="$CPU_MODEL,$CPU_FLAGS"
  else
    CPU_FLAGS="$CPU_MODEL,$CPU_FEATURES,$CPU_FLAGS"
  fi
fi

return 0
