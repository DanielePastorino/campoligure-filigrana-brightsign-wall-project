' *
' * NEXMOSPHERE 2023
' *

'
' XY-240 X-Eye, AirButton  
' https://nexmosphere.com/document/Product%20Manual%20-%20X-Eye%20Presence%20&%20AirButton.pdf
'
function GetInstance_XY240() as Object
    obj = {
        serialPort : invalid
        pattern : "^X([\d]{3})([\w])\[(.*)\]\s*$"

        ' Sensor Parsing
        ' INPUT: string (serial message)
        ' OUTPUT: roArray ([0]: message, [1]:<sensor n.>, [2]:<A,B,...>, [3]:<value>)
        ParseSensor : function (msg as string) as Object
            if m.serialPort = invalid then return invalid
            regex = CreateObject("roRegex", m.pattern , "i")
            matches = regex.Match(msg.Trim())
            if matches <> invalid and matches.Count() > 0 then
                ' for each match in matches
                '     print match
                ' end for
                return matches
            else 
                return invalid
            end if
        end function

        ' Parsing [Dz=10],[Dv=09],...
        ParseValue : function(value as string) as integer
            if value = invalid or value = "" then return -1
            regex = CreateObject("roRegex", "^([\w]{2})\=([\d]*)\s*$" , "i")
            matches = regex.Match(value.Trim())
            if matches <> invalid and matches.Count() > 0 then
                ' for each match in matches
                '     print "*";match
                ' end for
                return val(matches[2])
            else 
                return -1
            end if
        end function

        ' Get any type of sensor value as string 
        GetSensorValue : function(value as string) as string
            if value = invalid or value = "" then return ""
            regex = CreateObject("roRegex", "=" , "")
            matches = regex.Split(value.Trim())
            if matches <> invalid and matches.Count() = 2 then
                ' for each match in matches
                '     print "--";match
                ' end for
                return matches[1]
            end if
            return ""
        end function

        ' Parsing [Dz=AB]
        ' ParseValueEx : function(value as string) as integer
        '     if value = invalid or value = "" then return -1
        '     regex = CreateObject("roRegex", "^([\w]{2})\=([\w]*)\s*$" , "i")
        '     matches = regex.Match(value.Trim())
        '     if matches <> invalid and matches.Count() > 0 then
        '         ' for each match in matches
        '         '     print "---";match
        '         ' end for
        '         if matches[2] = "AB" then
        '             return 1
        '         else
        '             return -1
        '         end if
        '     end if
        ' end function

        ' Send command 
        SendCommand : function(cmd as string) as Object
            if m.serialPort = invalid then return invalid
            print ">Send ";cmd
            m.serialPort.SendLine(cmd.Trim())
        end function

        ' Get Absolute Distace 0-250
        GetAbsoluteDistance : function() as Object
            if m.serialPort = invalid then return invalid
            print ">Send X001B[DIST?]"
            m.serialPort.SendLine("X001B[DIST?]")
        end function

        ' Get RAW data [Dr=distance:noise:signal:error]
        GetRawDistance : function() as Object
            if m.serialPort = invalid then return invalid
            print ">Send X001B[RAW?]"
            m.serialPort.SendLine("X001B[RAW?]")
        end function
    }
    return obj   
end function


' *****************************************************************************************************

' '
' ' Generic  
' '
' function NxGetVideoPathEx(id as String, data as Object) as String
' 	' PARSE data like this:
' 	' "signal": [
'     '   {
'     '     "id": "X001A[3]",
'     '     "path": "data\\contents\\v1.mp4"
'     '   },
'     '   {
'     '     "id": "X002A[3]",
'     '     "path": "data\\contents\\v2.mp4"
'     '   }
'     ' ]
' 	if data = invalid then return ""  
' 	for each elem in data
' 		if elem.id = id then 
' 			return elem.path
' 		end if
' 	end for
' 	return ""
' end function

' ' Generic Obj
' function ConstructMyObject()
' 	obj = {
' 		Value	: 0
' 		TestArr	: CreateObject("roAssociativeArray") 

' 		Set		: function(x as integer) : m.Value = x : end function
' 		Get		: function() as integer : return m.Value : end function
' 		SetArr  : function(index as string, value as integer)
' 					m.TestArr[index] = value
' 				  end function
' 		GetArr  : function(s as string) : return m.TestArr[s] : end function 
' 		Pippo	: function(n as integer)
' 					print "###"
' 					m.Value = n + m.Value
' 				  end function
' 		Pluto	: function(s as string) as string
' 					return s
' 				  end function
' 	}
' 	return obj
' end function