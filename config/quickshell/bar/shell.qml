//@ pragma UseQApplication

import Quickshell
import QtQuick
import "core"

ShellRoot {
    id: root

    StateService {
        id: variantState
    }

    VariantHost {
        id: variantHost
        stateService: variantState
        v1Source: Qt.resolvedUrl("VariantRoot.qml")
        v2Source: Qt.resolvedUrl("VariantRoot.qml")   // V2 removed → always V1
    }

    IpcRouter {
        variantHost: variantHost
    }
}
