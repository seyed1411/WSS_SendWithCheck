import BigInt
import Bignum
import Dispatch
import Foundation


let secretMessage = "AVerySecretMessage!"
let secret = Bignum(data: secretMessage.data(using: .utf8)!)
while true {
    print()
    print("Welcome to WSS_Share and SendWithCheck Experiment")
    print("For run Runtime and Message Experiment, press 1")
    print("For run Memory Usage With SendWithCheck protocol, press 2")
    print("For run Memory Usage Without SendWithCheck protocol, press 3")
    print("For quit, press q")
    var input = readLine()
    switch input {
    case "1":
        RuntimeAndMessageExperiment()
    case "2":
        MemoryUsageWithSendWithCheckExperiment()
    case "3":
        MemoryUsageExperiment()     
        break
    case "q":
        print("End of Experiment")
        exit(0)
    default:
        continue        
    }
}

func RuntimeAndMessageExperiment(){
    var n = 5
    var t = 5
    var power = 0 
    print("========================================")
    print("ً** Ready to measer run-time **")
    print("========================================")
    print("ً** 1. WSS_Share without SendWithCheck**")
    // Create a dealer to initiate a WSS instance without SendWithCheck protocol.
    let dealer = Participant()

    // Create Participants p1, p2, ... pn.
    var player_pool: [Participant] = []
        
    while(n <= 500){
        player_pool.removeAll()
        for _ in 1...n{
            player_pool.append(Participant(wssInstance: dealer.wssInstance))
        }
        let startTime = DispatchTime.now()
        // Dealer that shares the secret among p1, p2 and p3.
        let numOfMessages = dealer.WSS_Share(secret: secret, players: player_pool, threshold: t)
        let endTime = DispatchTime.now()
        let nanoTime = endTime.uptimeNanoseconds - startTime.uptimeNanoseconds // <<<<< Difference in nano seconds (UInt64)
        let timeInterval = Double(nanoTime) / 1_000_000_000 // Technically could overflow for long running tests

        print("For n = \(n) system took: \"\(timeInterval)\" seconds and exchanged \"\(numOfMessages)\"")
        power += 50  
        n = power
        t = n
    }

    
    print("----------------------------------------")
    print("ً** 2. WSS_Share with SendWithCheck**")
    // Create a dealer to initiate a WSS instance with SendWithCheck protocol.
    let dealer2 = ParticipantSWC()

    // Create Participants p1, p2, ... pn.
    var player_pool2: [ParticipantSWC] = []
    n=5
    t=5
    power = 0
    while(n <= 500){
        player_pool2.removeAll()
        for _ in 1...n{
            player_pool2.append(ParticipantSWC(wssInstance: dealer.wssInstance))
        }
        let startTime = DispatchTime.now()
        // Dealer that shares the secret among p1, p2 and p3.
        let numOfMessages = dealer2.WSS_Share(secret: secret, players: player_pool2, threshold: t)
        let endTime = DispatchTime.now()
        let nanoTime = endTime.uptimeNanoseconds - startTime.uptimeNanoseconds // <<<<< Difference in nano seconds (UInt64)
        let timeInterval = Double(nanoTime) / 1_000_000_000 // Technically could overflow for long running tests

        print("For n = \(n) system took: \"\(timeInterval)\" seconds and exchanged \"\(numOfMessages)\"")
        power += 50  
        n = power
        t = n
    }
    print("========================================")
    print()
}




func MemoryUsageExperiment(){        
    var n = 5
    var t = 5    
    var power = 0
    print("========================================")
    print("ً** Ready to measer memory usage       **")
    print("ً** WSS_Share without SendWithCheck    **")
    print("========================================")
    print("** If you are using linux, we stop program after each step of n and you can see memory usage with following command:")
    print("** ID=$(pgrep SendWithCheck)")
    print("** grep VmPeak /proc/$ID/status")
    // Create a dealer to initiate a WSS instance without SendWithCheck protocol.
    let dealer = Participant()

    // Create Participants p1, p2, ... pn.
    var player_pool: [Participant] = []
    print("Ready for start? Press Enter")
    readLine()
    while (n <= 500){      
        player_pool.removeAll()
        
        for _ in 1...n{
            player_pool.append(Participant(wssInstance: dealer.wssInstance))
        }
        print("For n = \(n) wait for executing ...")
        // Dealer that shares the secret among p1, p2 and p3.
        dealer.WSS_Share(secret: secret, players: player_pool, threshold: t)                   
        print("Complited. Run the above commands on separte terminal to see memory consumption. Then press Enter.")
        readLine()                
        power += 50  
        n = power
        t = n
    }    
}

func MemoryUsageWithSendWithCheckExperiment(){
    var n = 5
    var t = 5
    var power = 0
    print("========================================")
    print("ً** Ready to measer memory usage       **")
    print("ً** WSS_Share with SendWithCheck       **")
    print("========================================")
    print("** If you are using linux, we stop program after each step of n and you can see memory usage with following command:")
    print("** ID=$(pgrep SendWithCheck)")
    print("** grep VmPeak /proc/$ID/status")

    // Create a dealer to initiate a WSS instance with SendWithCheck protocol.
    let dealer2 = ParticipantSWC()

    // Create Participants p1, p2, ... pn.
    var player_pool2: [ParticipantSWC] = []
    
    print("Ready for start? Press Enter")
    readLine()
    while (n <= 500){
        
        player_pool2.removeAll()        
        for _ in 1...n{
            player_pool2.append(ParticipantSWC(wssInstance: dealer2.wssInstance))
        }
        print("For n = \(n) wait for executing ...")
        // Dealer that shares the secret among p1, p2 and p3.
        dealer2.WSS_Share(secret: secret, players: player_pool2, threshold: t)
        print("Complited. Run the above commands on separte terminal to see memory consumption. Then press Enter.")
        readLine()
        power += 50  
        n = power
        t = n
    }
    print("========================================")
}

@discardableResult
func shell(_ args: String...) -> String {
    let task = Process()
    let pipe = Pipe()
    task.standardOutput = pipe
    task.launchPath = "/usr/bin/env"
    task.arguments = args
    task.launch()
    task.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8)!

    return output.filter("0123456789.".contains).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
}