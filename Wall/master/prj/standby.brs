Library "prj\utilsplus.brs"

Sub Main(cfg as Dynamic)
    objConfig =  ReadConfigJson("..\\config\\config.json")

    ' Abilito la funzionalità delle zone.
    ' Quando le zone sono abilitate l'image layer sta sempre davanti al video layer.
    ' Quando invece le zone non sono abilitate l'image layer non è visibile se c'è un video in riproduzione, e viceversa.
    EnableZoneSupport(false)

    ' la messagePort in ascolto sugli eventi
    messagePort = CreateObject("roMessagePort")

    ' =========== VIDEO CONFIG =========== 
    ' Risoluzione dello schermo ("1920x1080x60p", "1024x768x60p", "1280x800x60p", "1360x768x60")
    screenMode = objConfig.video.screenmode
    videoMode = CreateObject("roVideoMode")
    ' Imposto la modalità video e recupero le info
    videoMode.SetMode(screenMode)

	' ========== TIMER ==========
	if objConfig.server.enabled then
        timer = CreateObject("roTimer")
        timer.SetPort(messagePort)
        timer.SetElapsed(objConfig.server.every, 0)
        timer.SetUserData({name: "timerIAmAlive"})
    end if

    ' =========== OTHER CONFIG ===========
    mediaObj = objConfig.media.signal
    if objConfig.server.enabled then timer.Start()

    print "*** STANDBY MODE  ***"
    print "*** POWER SAVE ON ***"
'****************************
'* 		   STANDBY    		*
'****************************

_MainLoop:

    '... 
    videoMode.SetPowerSaveMode(true)

_MsgLoop:

    ' Attende senza timeout che arrivi un messaggio
    msgReceived = wait(0, messagePort)
    
    ' Timers
    if type(msgReceived) = "roTimerEvent" then
		mto = msgReceived.GetUserData()
        if mto <> invalid then
            ' Timer per I Am Alive
            if objConfig.server.enabled and mto.name = "timerIAmAlive" then
                body = { id : objConfig.name }
                print "###-PUT request: ";AsyncHttpPut(objConfig.server.url, body, messagePort)
                timer.Start()
            end if
        end if

	' Eventi URL
	else if type(msgReceived) = "roUrlEvent" then
		responseCode = msgReceived.GetResponseCode()
		print ">>>HTTP Response Code:";responseCode
		print "---------------------"
		print msgReceived.GetString()
		print "---------------------"

    end if

    goto _MsgLoop

End Sub