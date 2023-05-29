Library "prj\utilsplus.brs"

Sub Main() as Dynamic
    out = invalid
    objConfig = ReadConfigJson("..\config\baseconfig.json")
    if objConfig <> invalid then
        ' =========== RETE CONFIG ===========
        NetConfiguration(objConfig.rete)

        ' Abilito/disabilito SSH per debug
        if (objConfig.rete.ethernet.enable and objConfig.debug.ssh)
            EnableSSHDebug()
        else
            DisableSSHDebug()
        end if

        ' =========== WEB SERVER ===========
        if (objConfig.rete.ethernet.enable) then
            EnableLocalWebServer()
        end if

        out = objConfig
    end if
    return out
End Sub