pragma Singleton
import Quickshell
import "."

Singleton {
    id: root

    function doLayout( layoutAlgorithm, windowList, width, height) {
        return SmartGridLayout.doLayout(windowList, width, height)
    }
}
