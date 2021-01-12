# Rust Python script written in a python script
# Done instead of working on Helicity yw yw
# Made by Tactical BFG and if you remove this ill FUCKING SUE YOU

# Required libraries:
#   pip install win32api       <-- Used for mouse movements and to check if ur aiming and firing and the voices in my head

# Only tested on python 3.8.5 but it should work on most 3.5+ versions of python i think

import win32api, win32con, win32com.client
import os
import time

#  : Settings :
keybind = win32con.VK_F2
myPythonIsJewish = True # If it's too much recoil control, set to true, else set to False



# : Dont touch below (especially andrew) :

oldLeft = win32api.GetKeyState(1)
oldRight = win32api.GetKeyState(2)

on = False
fired = False;

demon = win32com.client.Dispatch("SAPI.SpVoice")
demon.Speak("artemis jewish boy in a boxcar shit hacks v1 initialized - written by tactical bfg")

while True:
    newLeft = win32api.GetKeyState(1)
    newRight = win32api.GetKeyState(2)

    if (win32api.GetAsyncKeyState(keybind)):
        on = not on
        if (on):
            demon.Speak("python recoil script on")
        else:
            demon.Speak("python recoil script off")

    if (oldLeft != newLeft):
        oldLeft = newLeft
        if (newLeft == 0 or newLeft > 0):
            fired = False

        if (newLeft < 0 and newRight < 0 and not fired and on):
            dY = 274
            if (myPythonIsJewish):
                dY = 68
            win32api.mouse_event(win32con.MOUSEEVENTF_MOVE, 1, dY, 0, 0)
            fired = True

    time.sleep(0.001)