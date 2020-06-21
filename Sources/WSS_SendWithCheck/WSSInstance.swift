import Foundation
import Dispatch
import BigInt
import Bignum
import CryptoSwift

/// A WSSInstance represents an instance of a Weak verifiable secret sharing scheme, i.e. a set of parameters used for all the operations during the secret sharing process like distribution of the shared secret.
public struct WSSInstance {
  public let alpha: Bignum
  public let q: Bignum
  public let g: Bignum
  public let G: Bignum
  
  public let length: Int
  
  public init(length: Int, q: Bignum, g: Bignum, G: Bignum, alpha: Bignum) {
    self.length = length
    self.q = q
    self.g = g
    self.G = G
    self.alpha = alpha
  }
  
  /// Initializes a WSSInstance by generating a safe prime of `length` bit length. `2` and the corresponding sophie germain prime are generators.
  ///
  /// - Parameter length: Number of bits used for choosing numbers and doing calculations.
  public init(length: Int) {
    // Find safe prime
    var q = BigUInt.randomInteger(withExactWidth: length)
    if q % 2 == 0 {
      q -= 1
    }
    var sophieGermainCandidate: BigUInt
    
    repeat {
      repeat {
        q -= 2
      } while !q.isPrime()
      sophieGermainCandidate = (q-1).quotientAndRemainder(dividingBy: 2).quotient
//      sophieGermainCandidate = (q-1).divided(by: 2).quotient
    } while !sophieGermainCandidate.isPrime()
    
    let qConverted = Bignum(q.description)
    let g = Bignum(sophieGermainCandidate.description)
    let G = Bignum(2)
    let alpha = Bignum(1024)

    self.init(length: length, q: qConverted, g: g, G: G, alpha: alpha)
  }
  
  /// Initializes a WSSInstance with default parameters. `q` is a safe prime of length 2048 bit (RFC3526). `2` and the corresponding sophie germain prime are generators.
  public init() {
    let q = BigUInt(stringLiteral: "32317006071311007300338913926423828248817941241140239112842009751400741706634354222619689417363569347117901737909704191754605873209195028853758986185622153212175412514901774520270235796078236248884246189477587641105928646099411723245426622522193230540919037680524235519125679715870117001058055877651038861847280257976054903569732561526167081339361799541336476559160368317896729073178384589680639671900977202194168647225871031411336429319536193471636533209717077448227988588565369208645296636077250268955505928362751121174096972998068410554359584866583291642136218231078990999448652468262416972035911852507045361090559")
    let g = Bignum((q-1).quotientAndRemainder(dividingBy: 2).quotient.description)
    let G = Bignum(2)
    let length = 2048
    let alpha = Bignum(1024)
    
    let qConverted = Bignum(q.description)
    
    self.init(length: length, q: qConverted, g: g, G: G, alpha: alpha)
  }
  
  public func generatePrivateKey() -> Bignum {
    let q = BigUInt(self.q.description)!
    var key = BigUInt.randomInteger(lessThan: q)
    
    // We need the private key and q-1 to be coprime so that we can calculate 1/key mod (q-1) during secret reconstruction.
    while key.greatestCommonDivisor(with: q - 1) != 1 {
      key = BigUInt.randomInteger(lessThan: q)
    }
    return Bignum(key.description)
  }
  
  public func generatePublicKey(privateKey: Bignum) -> Bignum {
    return mod_exp(G, privateKey, q)
  }
  
  /// Verifies that the shares the distribution bundle consists are consistent so that they can be used to reconstruct the secret later.
  ///
  /// - Parameter distributionBundle: The distribution bundle whose consistency is to be verified.
  /// - Returns: Returns `true` if the shares are correct and `false` otherwise.
  public func verify(distributionBundle: DistributionBundle) -> Bool {
    var digest = SHA2(variant: .sha256)
    
    for key in distributionBundle.publicKeys {
      guard let position = distributionBundle.positions[key],
        let response = distributionBundle.responses[key],
        let share = distributionBundle.shares[key] else {
          return false
      }
      
      // Calculate X_i
      var x: Bignum = 1
      var exponent: Bignum = 1
      for j in 0..<distributionBundle.commitments.count {
        x = (x * mod_exp(distributionBundle.commitments[j], exponent, q)) % q
        exponent = (exponent * Bignum(position)) % (q-1)
      }
      
      // Calculate a_1i, a_2i
      let a1 = (mod_exp(g, response, q) * mod_exp(x, distributionBundle.challenge, q)) % q
      let a2 = (mod_exp(key, response, q) * mod_exp(share, distributionBundle.challenge, q)) % q
      
      // Update hash
      let _ = try! digest.update(withBytes: Array(x.description.data(using: .utf8)!))
      let _ = try! digest.update(withBytes: Array(share.description.data(using: .utf8)!))
      let _ = try! digest.update(withBytes: Array(a1.description.data(using: .utf8)!))
      let _ = try! digest.update(withBytes: Array(a2.description.data(using: .utf8)!))
    }
    
    // Calculate challenge
    let challengeHash = try! digest.finish().toHexString()
    let challengeInt = Bignum(hex: challengeHash) % (q-1)
    
    return challengeInt == distributionBundle.challenge
  }
  
  /// Verifies if the share in the share bundle was decrypted correctly by the respective participant.
  ///
  /// - Parameters:
  ///   - shareBundle: The share bundle containing the share to be verified.
  ///   - distributionBundle: The distribution bundle that contains the share.
  ///   - publicKey: The public key of the sender of the share bundle.
  /// - Returns: Returns `true` if the share in the share bundle matches the decryption of the encrypted share and `false` otherwise.
  public func verify(shareBundle: ShareBundle, distributionBundle: DistributionBundle, publicKey: Bignum) -> Bool {
    let shareCandidate = distributionBundle.shares[publicKey]
    guard let share = shareCandidate else {
      return false
    }
    return verify(shareBundle: shareBundle, encryptedShare: share)
  }
  
  /// Verifies if the share in the share bundle was decrypted correctly by the respective participant.
  ///
  /// - Parameters:
  ///   - shareBundle: The share bundle containing the share to be verified.
  ///   - encryptedShare: The encrypted share from the distribution bundle.
  /// - Returns: Returns `true` if the share in the share bundle matches the decryption of the encrypted share and `false` otherwise.
  public func verify(shareBundle: ShareBundle, encryptedShare: Bignum) -> Bool {
    var digest = SHA2(variant: .sha256)
    
    let a1 = (mod_exp(G, shareBundle.response, q) * mod_exp(shareBundle.publicKey, shareBundle.challenge, q)) % q
    let a2 = (mod_exp(shareBundle.share, shareBundle.response, q) * mod_exp(encryptedShare, shareBundle.challenge, q)) % q
    
    let _ = try! digest.update(withBytes: Array(shareBundle.publicKey.description.data(using: .utf8)!))
    let _ = try! digest.update(withBytes: Array(encryptedShare.description.data(using: .utf8)!))
    let _ = try! digest.update(withBytes: Array(a1.description.data(using: .utf8)!))
    let _ = try! digest.update(withBytes: Array(a2.description.data(using: .utf8)!))
    
    let challengeHash = try! digest.finish().toHexString()
    let challengeInt = Bignum(hex: challengeHash) % (q-1)
    
    return challengeInt == shareBundle.challenge
  }
}
