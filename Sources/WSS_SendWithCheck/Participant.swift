import Foundation
import BigInt
import Bignum
import CryptoSwift

/// A participant represents one party in the secret sharing scheme. The participant can share a secret among a group of other participants and is then called the "dealer". The receiving participants that receive a part of the secret can use it to reconstruct the secret Therefore the partticipants need to collaborate and exchange their parts.
public class Participant {
  public let wssInstance: WSSInstance
  
  public var firstAlpha: (x: Bignum, y:Bignum, z:Bignum)
  public var primeAlpha: (x: Bignum, y:Bignum, z:Bignum)
  public var ICSetupAsINT: (s: Bignum, s_pr: Bignum, y: Bignum, y_pr: Bignum, z: Bignum, z_pr:Bignum)
  public var ICSetupAsREC: (alpha:Bignum, z:Bignum, z_pr:Bignum)
  public var d: Bignum = 0
  public var ICValidate_d: Bignum = 0
  public var ICValidateAsREC: (d: Bignum, s_pr_plus_ds: Bignum, y_pr_plus_dy: Bignum)
  public var output: [(s: Bignum, y:Bignum, z:Bignum)] = []
  
  public init(wssInstance: WSSInstance) {
    self.wssInstance = wssInstance
    firstAlpha = (Bignum(0),Bignum(0),Bignum(0))
    primeAlpha = (Bignum(0),Bignum(0),Bignum(0))
    ICSetupAsINT = (Bignum(0),Bignum(0),Bignum(0),Bignum(0),Bignum(0),Bignum(0))
    ICSetupAsREC = (Bignum(0),Bignum(0),Bignum(0))
    ICValidateAsREC = (Bignum(0),Bignum(0),Bignum(0))
  }
  
  /// Initializes a new participant with the default PVSS instance.
  public convenience init() {
    self.init(wssInstance: WSSInstance())
  }
   
  public func WSS_Share(secret: Bignum, players: [Participant], threshold: Int) -> Int {
    let polynomial = Polynomial(degree: threshold, secret: secret, randomThreshold: wssInstance.q)
    return WSS_Share(secret: secret, players: players, threshold: threshold, polynomial: polynomial)
  }

  public func WSS_Share(secret: Bignum, players: [Participant], threshold: Int, polynomial: Polynomial) -> Int {
    // initial verification
    assert(threshold <= players.count)
    
    var retNumofExchangedMessages = 0

    // Data the distribution bundle is going to be consisting of
    var shares: [Bignum] = []
    
    
    // Round 1
    // calculate s_i with polinomial    
    for i in 0..<(threshold-1) {
      shares.append(polynomial.getValue(x: Bignum(i+1)))
    }
    // send each player's share using ICSetup
    for i in 0..<(threshold-1) {
      for j in 0..<(threshold-1){
        if (i != j){
          retNumofExchangedMessages += ICSetup(I: players[i], R: players[j], s: shares[i])
        }
      }
    }

    // Round 2-5
    for i in 0..<(threshold-1) {
      for j in 0..<(threshold-1){
        if (i != j){
          retNumofExchangedMessages += ICValidate(I: players[i], R: players[j], s: shares[i])
        }
      }
    }
    // Validation in Shring phase


    return retNumofExchangedMessages
  }

  public func ICSetup(I: Participant, R: Participant, s: Bignum) -> Int{
    let firstA = OneAlphaConsistent(alpha: wssInstance.alpha, x: s)
    self.firstAlpha.x = firstA.x
    self.firstAlpha.y = firstA.y
    self.firstAlpha.z = firstA.z
    let primeA = OneAlphaConsistent(alpha: wssInstance.alpha)
    self.primeAlpha.x = primeA.x
    self.primeAlpha.y = primeA.y
    self.primeAlpha.z = primeA.z


    //SEND ON PRIVATE CHANNEL
    //SendRegular(sender: self, receiver: I, message: ())
    I.ICSetupAsINT = (firstA.x,primeA.x,firstA.y,primeA.y,firstA.z,primeA.z)
    //SEND ON PRIVATE CHANNEL
    R.ICSetupAsREC = (firstA.alpha,firstA.z,primeA.z)

    return 2     
  }

  public func ICValidate(I: Participant, R: Participant, s: Bignum) -> Int{
    I.choose_d()
    //SEND ON PRIVATE CHANNEL
    self.ICValidate_d = I.d
     
    let D_view: (d: Bignum, s_pr_plus_ds: Bignum, y_pr_plus_dy: Bignum)
    D_view = (self.ICValidate_d,self.primeAlpha.x + (self.firstAlpha.x * self.ICValidate_d), self.primeAlpha.y + (self.firstAlpha.y * self.ICValidate_d))
    //SEND ON PRIVATE CHANNEL
    R.ICValidateAsREC = D_view

    //DISTRIBUTE ON PUBLIC BROADCAST CHANNEL
    //we consider the DisChannel_ICValidate tuple to simulate a common broadcast channel
    let DisChannel_ICValidate: (dealer: Participant, inter: Participant, reci: Participant, r_reject: Bool) = (self,I,R,R.checkAlphaConsistency())
    
    //conflict checking based on data on public channel
    let I_view: (d: Bignum, s_pr_plus_ds: Bignum, y_pr_plus_dy: Bignum)
    I_view = (DisChannel_ICValidate.inter.d,DisChannel_ICValidate.inter.ICSetupAsINT.s_pr + (DisChannel_ICValidate.inter.ICSetupAsINT.s * DisChannel_ICValidate.inter.d), DisChannel_ICValidate.inter.ICSetupAsINT.y_pr + (DisChannel_ICValidate.inter.ICSetupAsINT.y * DisChannel_ICValidate.inter.d))
    let firstConflict: Bool = (I_view != D_view)
    let secondConflict: Bool = ((D_view != DisChannel_ICValidate.reci.ICValidateAsREC) || (!firstConflict && DisChannel_ICValidate.r_reject))
    if !(firstConflict || secondConflict){      
      R.output.append((self.firstAlpha.x, self.firstAlpha.y,self.firstAlpha.z))
      I.output.append((self.firstAlpha.x, self.firstAlpha.y,self.firstAlpha.z))
      // phase ended here
    }
    else {
      if(firstConflict){
        //DISTRIBUTE ON PUBLIC BROADCAST CHANNEL
        //we consider the DisChannel_ICValidate tuple to simulate a common broadcast channel
        let DisChannel_ICValidate2: (s: Bignum, y: Bignum) = (self.firstAlpha.x, self.firstAlpha.y)
        R.adjust_output_z(x: DisChannel_ICValidate2.s, y: DisChannel_ICValidate2.y)
        I.output.append((self.firstAlpha.x, self.firstAlpha.y,self.firstAlpha.z))
        // phase ended here
      }else{
        //DISTRIBUTE ON PUBLIC BROADCAST CHANNEL
        //we consider the DisChannel_ICValidate tuple to simulate a common broadcast channel
        let DisChannel_ICValidate2: (z: Bignum, alpha: Bignum) = (self.firstAlpha.z, wssInstance.alpha)
        R.output.append((self.firstAlpha.x, self.firstAlpha.y,self.firstAlpha.z))
        I.adjust_output_y(x: self.firstAlpha.x, z: DisChannel_ICValidate2.z)                
        // phase ended here
      }
    }
    return 2
  }

  public func choose_d(){
    self.d = Bignum(BigUInt.randomInteger(lessThan: 2048).description)
  }

  public func checkAlphaConsistency()-> Bool{
    return OneAlphaConsistent.isAlphaConsistent(alpha: self.ICSetupAsREC.alpha,x: self.ICValidateAsREC.s_pr_plus_ds,y: self.ICValidateAsREC.y_pr_plus_dy, z: (self.ICSetupAsREC.z_pr+(self.ICValidate_d*self.ICSetupAsREC.z)))
  }

  public func adjust_output_z(x: Bignum, y:Bignum){
    let temp: (s: Bignum, y: Bignum, z: Bignum) = (x,y,OneAlphaConsistent.computeZ(x: x, y: y))
    self.output.append(temp)
  }
  public func adjust_output_y(x: Bignum, z:Bignum){
    let temp: (s: Bignum, y: Bignum, z: Bignum) = (x,OneAlphaConsistent.computeY(x: x, z: z),z)
    self.output.append(temp)
  }
}
