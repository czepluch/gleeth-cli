import argv
import gleeth/provider
import gleeth/rpc/types as rpc_types
import gleeth_cli/cli
import gleeth_cli/commands/abi_lookup
import gleeth_cli/commands/balance
import gleeth_cli/commands/block
import gleeth_cli/commands/block_number
import gleeth_cli/commands/call
import gleeth_cli/commands/chain_id
import gleeth_cli/commands/checksum
import gleeth_cli/commands/code
import gleeth_cli/commands/convert
import gleeth_cli/commands/decode_calldata
import gleeth_cli/commands/decode_revert
import gleeth_cli/commands/decode_tx
import gleeth_cli/commands/encode_calldata
import gleeth_cli/commands/estimate_gas
import gleeth_cli/commands/fee_history
import gleeth_cli/commands/four_byte
import gleeth_cli/commands/gas_price
import gleeth_cli/commands/get_logs
import gleeth_cli/commands/keccak
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
            cli.Keccak(input, is_hex) ->
              execute_offline(keccak.execute(input, is_hex))
            cli.FourByte(selector) ->
              execute_offline(four_byte.execute(selector))
            cli.AbiLookup(address, chain, output) ->
              execute_offline(abi_lookup.execute(address, chain, output))
            cli.EncodeCalldata(signature, params) -> {
              case encode_calldata.execute(signature, params) {
                Ok(_) -> Nil
                Error(err) -> print_error(err)
              }
            }
            _ -> {
              case create_provider(parsed_args.rpc_target) {
                Ok(p) ->
                  execute_command(parsed_args.command, p, parsed_args.json)
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

fn create_provider(
  target: cli.RpcTarget,
) -> Result(provider.Provider, rpc_types.GleethError) {
  case target {
    cli.RpcUrl(url) -> provider.new(url)
    cli.ChainPreset(name) ->
      case name {
        "mainnet" | "ethereum" -> Ok(provider.mainnet())
        "sepolia" -> Ok(provider.sepolia())
        _ ->
          Error(rpc_types.ConfigError(
            "Chain '"
            <> name
            <> "' has no built-in RPC. Use --rpc-url with a provider for this chain.",
          ))
      }
  }
}

fn execute_offline(result: Result(Nil, String)) -> Nil {
  case result {
    Ok(_) -> Nil
    Error(msg) -> formatting.print_error(msg)
  }
}

fn execute_command(
  command: cli.Command,
  p: provider.Provider,
  json: Bool,
) -> Nil {
  let result = case command {
    cli.BlockNumber -> block_number.execute(p, json)
    cli.Block(block_id) -> block.execute(p, block_id, json)
    cli.Balance(addresses, file) -> balance.execute(p, addresses, file, json)
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
    cli.ChainId -> chain_id.execute(p, json)
    cli.GasPrice -> gas_price.execute(p, json)
    cli.FeeHistory(block_count, newest_block, percentiles) ->
      fee_history.execute(p, block_count, newest_block, percentiles)
    cli.Nonce(address, block) -> nonce.execute(p, address, block, json)
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
    | cli.Selector(_, _)
    | cli.Keccak(_, _)
    | cli.EncodeCalldata(_, _)
    | cli.FourByte(_)
    | cli.AbiLookup(_, _, _) -> Ok(Nil)
  }

  case result {
    Ok(_) -> Nil
    Error(err) -> print_error(err)
  }
}

fn print_error(error: rpc_types.GleethError) -> Nil {
  formatting.print_error(rpc_types.error_to_string(error))
}
