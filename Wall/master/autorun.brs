' ***************************
' * Autorun 2023/04/12 1138
' ***************************
Library "prj\utilsplus.brs"

bsconfig = Run("prj\baseconfig.brs")
if bsconfig <> invalid then 
    registrySection = CreateObject("roRegistrySection", "custom-data")

    ' Se nel registro "error" NON esiste lo creo/reboot
    if not registrySection.Exists("error") then 
        print "[WRITE error 0]"
        registrySection.Write("error", "0")
        registrySection.Flush()
        RebootSystem()
    ' ... se "error" ESISTE ed è "=1" allora lo metto a 0 (non ho bisogno di fare reboot perchè quando esegue main.brs trovo valore giusto)
    else if val(registrySection.Read("error")) = 1 then   
        print "[RE-WRITE error 0]"
        registrySection.Write("error", "0")
        registrySection.Flush()
    end if

    ' Se nel registro "standby" NON esiste lo creo/reboot
    if not registrySection.Exists("standby") then
        print "[WRITE standby 0]"
        registrySection.Write("standby", "0")
        registrySection.Flush()
        RebootSystem()
    else
        standbyValue = val(registrySection.Read("standby"))
        print "[READ standby: ";standbyValue;"]"
        if standbyValue > 0 then
            ' standby.brs
            print bsconfig.standbyscript.folder+"\"+bsconfig.standbyscript.file
            if FileExists(bsconfig.standbyscript.folder, bsconfig.standbyscript.file) then
                Run(bsconfig.standbyscript.folder+"\"+bsconfig.standbyscript.file, bsconfig)
            else
                print "***ERROR:";bsconfig.standbyscript.folder+"\"+bsconfig.standbyscript.file;" NOT EXISTS!"
            end if
        else
            ' main.brs
            print bsconfig.mainScript.folder+"\"+bsconfig.mainScript.file
            if FileExists(bsconfig.mainScript.folder, bsconfig.mainScript.file) then
                Run(bsconfig.mainScript.folder+"\"+bsconfig.mainScript.file, bsconfig)
            else
                print "***ERROR:";bsconfig.mainScript.folder+"\"+bsconfig.mainScript.file;" NOT EXISTS!"
            end if
        end if
    end if
    
end if

BreakIfRunError(LINE_NUM, registrySection)
' FINE
print "[END] autorun.brs"
' Esce e prompt SSH
End
