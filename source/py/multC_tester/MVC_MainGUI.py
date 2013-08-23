# -*- coding: utf-8 -*-

"""
Module implementing Control.
"""

from PyQt4.QtGui import QDialog
from PyQt4.QtCore import pyqtSignature, pyqtSlot
from PyQt4.QtCore import QTimer,  SIGNAL, SLOT, Qt,  QRect
from PyQt4 import QtCore, QtGui

from Utilities import *
from generate_sin import gen as gen_sin
from generate_tri import gen as gen_tri
from generate_spikes import spike_train
from generate_sequence import gen as gen_ramp
from math import floor,  pi
import types
from functools import partial
#from par_search import muscle_properties
from Utilities import convertType
#from M_Fpga import SendPara

from Ui_MVC_MainGUI import Ui_Dialog



class MultiXemScheduler(QDialog, Ui_Dialog):
    """
    GUI class for feeding waveforms or user inputs to OpalKelly boards
    """
    def __init__(self, xemList, cList, vList,  halfCountRealTime, parent = None):
        """
        Constructor
        """
        QDialog.__init__(self, parent)
        self.setupUi(self)
        self.move(300, 10)   # windows position
        self.xemList = xemList
        self.cList = cList
        self.vList = vList
        self.halfCountRealTime = halfCountRealTime

#        self.cList.setWindowTitle('Global Control')
        #self.cList.show() 

#        self.jointAngle = 0.0  # initial joint 
#        self.best_ForceDiff = 1.0 * 0xFFFF  #inital muscle length difference (arbitrary)
#        self.start = False
       
       
        
        self.onClkRate(5) 
#        self.startSim()
        


    def onClkRate(self, value):   
        """ value = how many times of 1/10 real-time
        """
        # F_fpga = C * NUM_NEURON * V * F_emu ,  (C : cycles_per_neuron = 2,  V = 365)
        # if F_fpga = 200Mhz,  F_emu = 1khz)
        # halfcnt = F_fpga / F_neuron / 2 = F_fpga / (C * NUM_NEURON * V * F_emu) / 2
        
        #self.clkRate = value
       
        
        newHalfCnt = self.halfCountRealTime * 10 / value        
        print value,  newHalfCnt
        
        for eachXem in self.xemList:
            eachXem.SendPara(bitVal = newHalfCnt, trigEvent = 7)
#
    @pyqtSignature("int")
    def on_horizontalSlider_sliderMoved(self, position):
        """
        Slot documentation goes here.
        """
        self.onClkRate(position)

    @pyqtSignature("bool")
    def on_pushButton_2_clicked(self, checked):
        """
        Slot documentation goes here.
        """
        for eachC in self.cList:
            eachC.close()

    @pyqtSignature("int")
    def on_horizontalSlider_valueChanged(self, value):
        """
        Slot documentation goes here.
        """
        self.onClkRate(value)

    @pyqtSignature("bool")
    def on_pushButton_4_clicked(self, checked):
        """
        Slot documentation goes here.
        """
        newResetGlobal = checked
        for eachXem in self.xemList:
            eachXem.SendButton(newResetGlobal, BUTTON_RESET)
#        self.xemList[1].SendButton(newResetGlobal, BUTTON_RESET)

    @pyqtSignature("bool")
    def on_pushButtonData_clicked(self, checked):
        """
        Toggling data logging for Matlab use.
        """
        for eachC in self.cList:
            eachC.isLogData = checked

    # this button starts the simulation 
    @pyqtSignature("bool")
    def on_pushButton_clicked(self, checked):
        """
        Slot documentation goes here.
        """
#        self.running = True

        for eachC in self.cList:
            eachC.startSim()
#        for eachV in self.vList:
#            print eachV
#            eachV.readParameters()

    
    @pyqtSignature("bool")
    def on_pushButton_burn_clicked(self, checked):
        """
        Slot documentation goes here.
        """
        bitFileList = []
        for eachV in self.vList:
            bitFileList.append(str(eachV.listWidget.currentItem().text()))
         
        print bitFileList
        for eachXem, eachBitFile in zip(self.xemList, bitFileList):
            eachXem.BurnBitFile(eachBitFile)
    
    @pyqtSignature("bool")
    def on_pushButton_reset_sim_clicked(self, checked):
        """
        Slot documentation goes here.
        """
        newResetSim = checked
        for eachXem in self.xemList:
            eachXem.SendButton(newResetSim, BUTTON_RESET_SIM)
    
   
    @pyqtSignature("bool")
    def on_checkBox_clicked(self, checked):
        """
        Slot documentation goes here.
        """
  
        if (checked):
            print "waveform sine_bic fed"
    #            pipeInData = spike_train(firing_rate = 10)      
            #pipeInData = gen_sin(F = 0.5, AMP = 5000.0,  BIAS = 5001.0,  T = 2.0) 
    #            pipeInData = gen_tri(T = 2.0) 

            pipeInData_bic = gen_sin(F = 1.0, AMP = 150000.0,  BIAS = 0.0,  T = 2.0) # was 15000

            pipeInDataBic=[]
            for i in xrange(0,  2048):
                pipeInDataBic.append(max(0.0,  pipeInData_bic[i]))


    #        elif choice == "middleBoard_sine_Tri":
            print "waveform sine_tri fed"

            pipeIndata_tri = -gen_sin(F = 1.0,  AMP = 150000.0,  BIAS = 0.0,  T = 2.0)

            pipeInDataTri=[]
            for i in xrange(0,  2048):
                pipeInDataTri.append(max(0.0,  pipeIndata_tri[i]))
   

            self.xemList[0].SendPipe(pipeInDataBic)
            self.xemList[1].SendPipe(pipeInDataTri)
