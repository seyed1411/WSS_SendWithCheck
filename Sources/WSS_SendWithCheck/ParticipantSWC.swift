import Foundation
import BigInt
import Bignum
import CryptoSwift

/// A ParticipantSWC represents one party in the secret sharing scheme with SendWithCheck. The participant can share a secret among a group of other participants and is then called the "dealer". The receiving participants that receive a part of the secret can use it to reconstruct the secret Therefore the partticipants need to collaborate and exchange their parts.
public class ParticipantSWC {
  public let wssInstance: WSSInstance
  
  // WSS message holder vars
  public var firstAlpha: (x: Bignum, y:Bignum, z:Bignum)
  public var primeAlpha: (x: Bignum, y:Bignum, z:Bignum)
  public var ICSetupAsINT: (s: Bignum, s_pr: Bignum, y: Bignum, y_pr: Bignum, z: Bignum, z_pr:Bignum)
  public var ICSetupAsREC: (alpha:Bignum, z:Bignum, z_pr:Bignum)
  public var d: Bignum = 0
  public var ICValidate_d: Bignum = 0
  public var ICValidateAsREC: (d: Bignum, s_pr_plus_ds: Bignum, y_pr_plus_dy: Bignum)
  public var output: [(s: Bignum, y:Bignum, z:Bignum)] = []
  
  // SendWithCheck message holder vars
  public var swc_dealer_m: Bignum = 0
  public var swc_dealer_rij: (r_i: Bignum, r_j: Bignum) = (Bignum(0),Bignum(0))
  public var swc_Pj_rj: Bignum = 0
  public var swc_Pi_ri: Bignum = 0
  public var swc_Pi_beta: Bignum = 0
  public var swc_Pi_m: Bignum = 0
  public var swc_Pi_alpha: Bignum = 0
  public var swc_Pi_REJECT: [ParticipantSWC] = []

  public init(wssInstance: WSSInstance) {
    self.wssInstance = wssInstance
    firstAlpha = (Bignum(0),Bignum(0),Bignum(0))
    primeAlpha = (Bignum(0),Bignum(0),Bignum(0))
    ICSetupAsINT = (Bignum(0),Bignum(0),Bignum(0),Bignum(0),Bignum(0),Bignum(0))
    ICSetupAsREC = (Bignum(0),Bignum(0),Bignum(0))
    ICValidateAsREC = (Bignum(0),Bignum(0),Bignum(0))
  }
  
  /// Initializes a new ParticipantSWC with the default PVSS instance.
  public convenience init() {
    self.init(wssInstance: WSSInstance())
  }
   
  // WSS functions
  public func WSS_Share(secret: Bignum, players: [ParticipantSWC], threshold: Int) -> Int {
    let polynomial = Polynomial(degree: threshold, secret: secret, randomThreshold: wssInstance.q)
    return self.WSS_Share(secret: secret, players: players, threshold: threshold, polynomial: polynomial)
  }

  public func WSS_Share(secret: Bignum, players: [ParticipantSWC], threshold: Int, polynomial: Polynomial) -> Int{
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
    return retNumofExchangedMessages
  }

  public func ICSetup(I: ParticipantSWC, R: ParticipantSWC, s: Bignum) -> Int{
    let firstA = OneAlphaConsistent(alpha: wssInstance.alpha, x: s)
    self.firstAlpha.x = firstA.x
    self.firstAlpha.y = firstA.y
    self.firstAlpha.z = firstA.z
    let primeA = OneAlphaConsistent(alpha: wssInstance.alpha)
    self.primeAlpha.x = primeA.x
    self.primeAlpha.y = primeA.y
    self.primeAlpha.z = primeA.z
    
    //SEND ON PRIVATE CHANNEL
    //SendWithCheck() function is used to simulate SendWithCheck protocol in every ((SEND ON PRIVATE CHANNEL))
    //w.l.o.g we simulate any tuple/complex messages as a new message with just the first member of that tuple/complex message
    // number of exchanged message = 6 (SendWithCheck) + 1 (FinalDecision)
    if(ParticipantSWC.SendWithCheck(dealer:self,P_i:I,P_j:self,m:firstA.x)){      
      I.ICSetupAsINT = (firstA.x,primeA.x,firstA.y,primeA.y,firstA.z,primeA.z)
    }else{
      I.swc_Pi_REJECT.append(self)
    }
    
    //SEND ON PRIVATE CHANNEL
    //SendWithCheck() function is used to simulate SendWithCheck protocol in every ((SEND ON PRIVATE CHANNEL))
    //w.l.o.g we simulate any tuple/complex messages as a new message with just the first member of that tuple/complex message
    // number of exchanged message = 6 (SendWithCheck) + 1 (FinalDecision)
    if(ParticipantSWC.SendWithCheck(dealer:self,P_i:R,P_j:self,m:firstA.alpha)){
      R.ICSetupAsREC = (firstA.alpha,firstA.z,primeA.z)
    }else{
      R.swc_Pi_REJECT.append(self)
    }
    return 14
  }

  public func ICValidate(I: ParticipantSWC, R: ParticipantSWC, s: Bignum) -> Int{
    I.choose_d()
    
    //SEND ON PRIVATE CHANNEL
    //SendWithCheck() function is used to simulate SendWithCheck protocol in every ((SEND ON PRIVATE CHANNEL))
    //w.l.o.g we simulate any tuple/complex messages as a new message with just the first member of that tuple/complex message
    // number of exchanged message = 6 (SendWithCheck) + 1 (FinalDecision)
    if(ParticipantSWC.SendWithCheck(dealer:self,P_i:self,P_j:I,m:I.d)){
      self.ICValidate_d = I.d
    }else {
      self.swc_Pi_REJECT.append(I)
    }

    let D_view: (d: Bignum, s_pr_plus_ds: Bignum, y_pr_plus_dy: Bignum)
    D_view = (self.ICValidate_d,self.primeAlpha.x + (self.firstAlpha.x * self.ICValidate_d), self.primeAlpha.y + (self.firstAlpha.y * self.ICValidate_d))
    
    //SEND ON PRIVATE CHANNEL
    //SendWithCheck() function is used to simulate SendWithCheck protocol in every ((SEND ON PRIVATE CHANNEL))
    //w.l.o.g we simulate any tuple/complex messages as a new message with just the first member of that tuple/complex message
    // number of exchanged message = 6 (SendWithCheck) + 1 (FinalDecision)
    if(ParticipantSWC.SendWithCheck(dealer:self,P_i:R,P_j:self,m:D_view.d)){      
      R.ICValidateAsREC = D_view
    }else {
      R.swc_Pi_REJECT.append(self)
    }

    //DISTRIBUTE ON PUBLIC BROADCAST CHANNEL
    //we consider the DisChannel_ICValidate tuple to simulate a common broadcast channel
    let DisChannel_ICValidate: (dealer: ParticipantSWC, inter: ParticipantSWC, reci: ParticipantSWC, r_reject: Bool) = (self,I,R,R.checkAlphaConsistency())
    
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
    return 14
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

  // SendWithCheck functions
  public func swc_select_random_numbers(){
    self.swc_dealer_rij = (Bignum(BigUInt.randomInteger(lessThan: 2048).description),Bignum(BigUInt.randomInteger(lessThan: 2048).description))
  }
  public func swc_is_message_acceptable() -> Bool{
    if((self.swc_Pi_beta - self.swc_Pi_alpha) == self.swc_Pi_ri){
      return true
    }
    return false 
  }
  public static func SendWithCheck(dealer: ParticipantSWC, P_i: ParticipantSWC, P_j: ParticipantSWC, m: Bignum) -> Bool{
    // each SendWithCheck needs 6 extra message exchange on private channels

    // P_j send message m to D
    dealer.swc_dealer_m = m

    // D chooses two random pad ri, rj
    dealer.swc_select_random_numbers()

    // D sends rj to Pj
    P_j.swc_Pj_rj = dealer.swc_dealer_rij.r_j

    // D sends ri and βji=ri+rj+m to Pi
    P_i.swc_Pi_ri = dealer.swc_dealer_rij.r_i
    P_i.swc_Pi_beta = dealer.swc_dealer_rij.r_i + dealer.swc_dealer_rij.r_j + m

    // Pj sends m and αji=rj+m to Pi
    P_i.swc_Pi_m = m
    P_i.swc_Pi_alpha = m + P_j.swc_Pj_rj

    return P_i.swc_is_message_acceptable()
  }
}
