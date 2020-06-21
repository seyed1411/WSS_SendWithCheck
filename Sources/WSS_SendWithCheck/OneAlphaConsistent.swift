import Foundation
import BigInt
import Bignum

public struct OneAlphaConsistent {
  let alpha: Bignum
  let x: Bignum
  let y: Bignum
  let z: Bignum
  
  public init(alpha: Bignum) {
    self.alpha = alpha
    self.x=0
    self.y=0
    self.z=0
  }

  public init(alpha: Bignum, x: Bignum) {
    self.alpha = alpha
    self.x = x
    self.y=0
    self.z=0
  }
  
  public init() {
    //should compute all
    alpha = Bignum(BigUInt.randomInteger(lessThan: 2048).description)
    self.x=0
    self.y=0
    self.z=0
  }
  
  // Calculate p(x)
  func computeXYZ() {
    
  }

  static func isAlphaConsistent(alpha: Bignum, x: Bignum, y: Bignum, z: Bignum) -> Bool{
    if true{
      return true
    }
    return false
  }

  static func computeZ(x: Bignum, y: Bignum) -> Bignum{
    return Bignum(0)
  }
  static func computeY(x: Bignum, z: Bignum) -> Bignum{
    return Bignum(0)
  }
}
