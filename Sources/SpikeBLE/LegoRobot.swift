//
//  LegoRobot.swift
//  LegoNXTiOS
//
//  Created by Matheus Tusi on 05/04/21.
//

import Foundation
import CoreBluetooth
import Combine

class LegoRobot: NSObject, ObservableObject {
    private var centralManager: CBCentralManager!
    private var legoPer: CBPeripheral?
    private var txChar: CBCharacteristic!
    private var rxChar: CBCharacteristic!
    private var txDesc: CBDescriptor!
    private var peripheralName: String!
    
    @Published var lastMessageFromRobot: String = ""
    @Published var isConnected: Bool = false
    
    init(peripheralName: String) {
        super.init()
        self.peripheralName = peripheralName
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }
    
    public func sendValue(string: String) {
        if isConnected {
            let valueString = (string as NSString).data(using: String.Encoding.utf8.rawValue)!
            if let lego = legoPer {
                if valueString.count < lego.maximumWriteValueLength(for: .withResponse) {
                    lego.writeValue(valueString, for: txChar, type: .withoutResponse)
                } else {
                    print("[SpikeBLE] Error message too long. you tried to send \(valueString.count) bytes but the robot only supports \(lego.maximumWriteValueLength(for: .withResponse)) bytes")
                }
            }
        }
    }
    
    
}

extension LegoRobot: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            central.scanForPeripherals(withServices: nil, options: nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        guard peripheral.name != nil else { return }
        
        if peripheral.name == self.peripheralName {
            print("[SpikeBLE] robot found!!")
            //stop scanning
            centralManager.stopScan()
            
            //connect
            centralManager.connect(peripheral, options: nil)
            self.legoPer = peripheral
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("[SpikeBLE] connected to: \(String(describing: peripheral.name))")
        self.isConnected = true
        //now we check if the robot supports UART protocol
        peripheral.delegate = self
        let UART = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
        peripheral.discoverServices([UART])
        
    }
    
    //Disconnected Re-starting scan
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if peripheral == legoPer {
            self.isConnected = false
            self.centralManager.scanForPeripherals(withServices: nil, options: nil)
        }
    }
}

extension LegoRobot: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if ((error) != nil) {
            print("[SpikeBLE] Error discovering services: \(error!.localizedDescription)")
            return
        }
        
        guard let services = peripheral.services else {
            return
        }
        //We need to discover the all characteristic
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
        print("[SpikeBLE] Discovered Services: \(services)")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if ((error) != nil) {
            print("[SpikeBLE] Error discovering services: \(error!.localizedDescription)")
            return
        }
        
        guard let characteristics = service.characteristics else {
            return
        }
        
        print("[SpikeBLE] Found \(characteristics.count) characteristics!")
        
        for characteristic in characteristics {
            //looks for the right characteristic
            
            if characteristic.uuid.isEqual(BLE_Characteristic_uuid_Rx)  {
                let rxCharacteristic = characteristic
                rxChar = rxCharacteristic
                
                //Once found, subscribe to the this particular characteristic...
                peripheral.setNotifyValue(true, for: rxCharacteristic)
                // We can return after calling CBPeripheral.setNotifyValue because CBPeripheralDelegate's
                // didUpdateNotificationStateForCharacteristic method will be called automatically
                peripheral.readValue(for: characteristic)
                print("[SpikeBLE] Rx Characteristic: \(characteristic.uuid)")
            }
            if characteristic.uuid.isEqual(BLE_Characteristic_uuid_Tx){
                txChar = characteristic
                print("[SpikeBLE] Tx Characteristic: \(characteristic.uuid)")
            }
            peripheral.discoverDescriptors(for: characteristic)
        }
    }
    
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.value != nil else { return }
        if let ASCIIstring = NSString(data: characteristic.value!, encoding: String.Encoding.utf8.rawValue) {
            self.lastMessageFromRobot = "\((ASCIIstring as String))"
            
        }
        
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        if error != nil {
            print("\(error.debugDescription)")
            return
        }
        if ((characteristic.descriptors) != nil) {
            
            for x in characteristic.descriptors!{
                let descript = x as CBDescriptor
                print("[SpikeBLE] function name: DidDiscoverDescriptorForChar \(String(describing: descript.description))")
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if (error != nil) {
            print("[SpikeBLE] Error changing notification state:\(String(describing: error?.localizedDescription))")
            
        } else {
            print("[SpikeBLE] Characteristic's value subscribed")
        }
        
        if (characteristic.isNotifying) {
            print ("[SpikeBLE] Subscribed. Notification has begun for: \(characteristic.uuid)")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            print("[SpikeBLE] Error discovering services: error")
            return
        }
        print("[SpikeBLE] Message sent")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor descriptor: CBDescriptor, error: Error?) {
        guard error == nil else {
            print("[SpikeBLE] Error discovering services: error")
            return
        }
        print("[SpikeBLE] Succeeded!")
    }
}
