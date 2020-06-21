import Foundation
import BigInt
import Bignum

public struct Polynomial {
  let coefficients: [Bignum]
  
  public init(coefficients: [Bignum]) {
    self.coefficients = coefficients
  }
  
  public init(degree: Int, secret: Bignum, randomThreshold: Bignum) {
    var coefficientList: [Bignum] = []
    coefficientList.append(secret)
    for _ in 1...degree {
      let less = BigUInt(randomThreshold.description)!
      coefficientList.append(Bignum(BigUInt.randomInteger(lessThan: less).description))
    }
    
   self.init(coefficients: coefficientList)
  }
  
  // Calculate p(x)
  public func getValue(x: Bignum) -> Bignum {
    var result = coefficients[0]
    var temp: Bignum = 1
    
    for i in 1..<coefficients.count {
      temp = (temp * x)
      result = (result + (coefficients[i] * temp))
    }
    
    return result
  }
}
