import argv
import gleeth/provider
import gleeth/rpc/types as rpc_types
import gleeth_cli/cli
import gleeth_cli/commands/balance
import gleeth_cli/commands/block_number
import gleeth_cli/commands/call
import gleeth_cli/commands/chain_id
import gleeth_cli/commands/checksum
import gleeth_cli/commands/code
import gleeth_cli/commands/convert
import gleeth_cli/commands/decode_calldata
import gleeth_cli/commands/decode_revert
import gleeth_cli/commands/decode_tx
import gleeth_cli/commands/estimate_gas
import gleeth_cli/commands/fee_history
import gleeth_cli/commands/gas_price
import gleeth_cli/commands/get_logs
import gleeth_cli/commands/nonce
import gleeth_cli/commands/receipt
import gleeth_cli/commands/recover
import gleeth_cli/commands/selector_cmd
import gleeth_cli/commands/send
import gleeth_cli/commands/storage_at
import gleeth_cli/commands/transaction as transaction_cmd
import gleeth_cli/commands/wait_receipt
import gleeth_cli/commands/wallet
import gleeth_cli/formatting

pub fn main() -> Nil {
  case argv.load().arguments {
    [] -> cli.show_help()
    args -> {
      case cli.parse_args(args) {
        Ok(parsed_args) -> {
          case parsed_args.command {
            cli.Help -> cli.show_help()
            cli.Wallet(wallet_args) -> execute_wallet_command(wallet_args)
            cli.Recover(recover_args) -> execute_recover_command(recover_args)
            cli.Checksum(address) -> execute_offline(checksum.execute(address))
            cli.Convert(value, from_unit, to_unit) ->
              execute_offline(convert.execute(value, from_unit, to_unit))
            cli.DecodeTx(raw_hex) -> execute_offline(decode_tx.execute(raw_hex))
            cli.DecodeCalldata(calldata, signature, abi_file, function_name) ->
              execute_offline(decode_calldata.execute(
                calldata,
                signature,
                abi_file,
                function_name,
              ))
            cli.DecodeRevert(data, abi_file) ->
              execute_offline(decode_revert.execute(data, abi_file))
            cli.Selector(signature, is_event) ->
              execute_offline(selector_cmd.execute(signature, is_event))
            _ -> {
              case provider.new(parsed_args.rpc_url) {
                Ok(p) -> execute_command(parsed_args.command, p)
                Error(err) -> print_error(err)
              }
            }
          }
        }
        Error(err) -> print_error(err)
      }
    }
  }
}

fn execute_wallet_command(wallet_args: List(String)) -> Nil {
  case wallet.parse_args(wallet_args) {
    Ok(operation) -> {
      case wallet.run(operation) {
        Ok(_) -> Nil
        Error(msg) -> formatting.print_error("Wallet error: " <> msg)
      }
    }
    Error(msg) -> {
      formatting.print_error("Invalid wallet command: " <> msg)
      wallet.print_usage()
    }
  }
}

fn execute_recover_command(recover_args: List(String)) -> Nil {
  case recover.parse_args(recover_args) {
    Ok(options) -> {
      case recover.run(options) {
        Ok(_) -> Nil
        Error(msg) -> formatting.print_error("Recover error: " <> msg)
      }
    }
    Error(msg) -> {
      formatting.print_error("Invalid recover command: " <> msg)
      recover.print_usage()
    }
  }
}

fn execute_offline(result: Result(Nil, String)) -> Nil {
  case result {
    Ok(_) -> Nil
    Error(msg) -> formatting.print_error(msg)
  }
}

fn execute_command(command: cli.Command, p: provider.Provider) -> Nil {
  let result = case command {
    cli.BlockNumber -> block_number.execute(p)
    cli.Balance(addresses, file) -> balance.execute(p, addresses, file)
    cli.Call(contract, function, parameters, abi_file) ->
      call.execute(p, contract, function, parameters, abi_file)
    cli.Transaction(hash) -> transaction_cmd.execute(p, hash)
    cli.Code(address) -> code.execute(p, address)
    cli.EstimateGas(from, to, value, data) ->
      estimate_gas.execute(p, from, to, value, data)
    cli.StorageAt(address, slot, block) ->
      storage_at.execute(p, address, slot, block)
    cli.GetLogs(from_block, to_block, address, topics) ->
      get_logs.execute(p, from_block, to_block, address, topics)
    cli.Send(to, value, private_key, gas_limit, data, legacy) ->
      send.execute(
        p,
        send.SendArgs(to, value, private_key, gas_limit, data, legacy),
      )
    cli.ChainId -> chain_id.execute(p)
    cli.GasPrice -> gas_price.execute(p)
    cli.FeeHistory(block_count, newest_block, percentiles) ->
      fee_history.execute(p, block_count, newest_block, percentiles)
    cli.Nonce(address, block) -> nonce.execute(p, address, block)
    cli.Receipt(hash) -> receipt.execute(p, hash)
    cli.Wait(hash, timeout) -> wait_receipt.execute(p, hash, timeout)
    // Offline commands, Wallet, and Help are handled in main()
    cli.Wallet(_)
    | cli.Help
    | cli.Recover(_)
    | cli.Checksum(_)
    | cli.Convert(_, _, _)
    | cli.DecodeTx(_)
    | cli.DecodeCalldata(_, _, _, _)
    | cli.DecodeRevert(_, _)
    | cli.Selector(_, _) -> Ok(Nil)
  }

  case result {
    Ok(_) -> Nil
    Error(err) -> print_error(err)
  }
}

fn print_error(error: rpc_types.GleethError) -> Nil {
  formatting.print_error(rpc_types.error_to_string(error))
}
