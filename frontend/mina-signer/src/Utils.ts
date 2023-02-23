import type {
  Payment,
  StakeDelegation,
  Message,
  ZkappCommand,
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

export function isZkappCommand(p: ZkappCommand): p is ZkappCommand {
  return p.hasOwnProperty("zkappCommand") && p.hasOwnProperty("feePayer");
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
