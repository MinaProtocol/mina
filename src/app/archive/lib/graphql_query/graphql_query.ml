module Base_types = Base_types
module Blocks = Blocks
module Fee_transfers = Fee_transfers
module Public_keys = Public_keys
module User_commands = User_commands

module Clear_data =
[%graphql
{|
  mutation clear  {

    delete_blocks_user_commands (where: {}) {
      affected_rows
    }

    delete_blocks_fee_transfers (where: {}) {
      affected_rows
    }
    
    delete_blocks_snark_jobs (where: {}) {
      affected_rows
    }

    delete_receipt_chain_hashes(where: {}) {
      affected_rows
    }

    delete_user_commands(where: {}) {
      affected_rows
    }

    delete_blocks(where: {}) {
      affected_rows
    }
      
    delete_public_keys(where: {}) {
      affected_rows
    }

  }
|}]
