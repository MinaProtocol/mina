import type {
  Payment,
  StakeDelegation,
  Message,
  Party,
  SignableData,
} from "./TSTypes";

function hasCommonProperties(data: SignableData) {
  return (
    data.hasOwnProperty("to") &&
    data.hasOwnProperty("from") &&
    data.hasOwnProperty("fee") &&
    data.hasOwnProperty("nonce")
  );
}

export function isParty(p: Party): p is Party {
  return p.hasOwnProperty("parties") && p.hasOwnProperty("feePayer");
}

export function isPayment(p: SignableData): p is Payment {
  return hasCommonProperties(p) && p.hasOwnProperty("amount");
}

export function isStakeDelegation(p: SignableData): p is StakeDelegation {
  return hasCommonProperties(p) && !p.hasOwnProperty("amount");
}

export function isMessage(p: SignableData): p is Message {
  return p.hasOwnProperty("publicKey") && p.hasOwnProperty("message");
}
