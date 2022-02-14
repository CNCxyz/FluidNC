# Subroutines to call esptool with common arguments

EsptoolPath=macos/esptool

BaseArgs="--chip esp32 --baud 230400"

SetupArgs="--before default_reset --after hard_reset write_flash -z --flash_mode dio --flash_freq 80m --flash_size detect"

esptool_basic () {
    echo $EsptoolPath $BaseArgs $*
    $EsptoolPath $BaseArgs $BaseArgs $*
    if test "$?" != "0"; then
        echo esptool failed
        exit 1
    fi
}
esptool_write () {
    esptool_basic $SetupArgs $*
}
check_security() {
    esptool_basic dump_mem 0x3ff5a018 4 SecurityFuses.bin

    if ! cmp -s SecurityFuses.bin common/SecurityFusesOK.bin ; then
        if ! cmp -s SecurityFuses.bin common/SecurityFusesOK0.bin ; then
            echo "*******************************************"
            echo "*  Secure boot is enabled on this ESP32   *"
            echo "* Loading FluidNC would probably brick it *"
            echo "*    !ABORTED! Read Wiki for more Info    *"
            echo "*******************************************"
            cmp -l SecurityFuses.bin common/SecurityFusesOK0.bin
            rm SecurityFuses.bin
            return 1
        fi
    fi

    rm SecurityFuses.bin
    return 0
}

esptool_erase() {
    if ! check_security; then
        exit
    fi
    esptool_basic erase_flash
}

Bootloader="0x1000 common/bootloader_dio_80m.bin"
Bootapp="0xe000 common/boot_app0.bin"
Firmware="0x10000 ${BuildType}/firmware.bin"
Partitions="0x8000 ${BuildType}/partitions.bin"

install() {
    if ! check_security; then
        exit
    fi
    esptool_write $Bootloader $Bootapp $Firmware $Partitions

    echo Starting fluidterm
    sh fluidterm.sh
}
