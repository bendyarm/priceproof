import {
  Account,
  ProgramManager,
  PrivateKey,
  initThreadPool,
  AleoKeyProvider,
  AleoNetworkClient,
  NetworkRecordProvider,
} from "@provablehq/sdk";
import { expose, proxy } from "comlink";

await initThreadPool();

async function localProgramExecution(program, aleoFunction, inputs, privateKey) {
  const programManager = new ProgramManager();

  // Create a temporary account for the execution of the program
  console.log("Private key: " + privateKey)
  const account = new Account({
    privateKey: privateKey,
  });

  programManager.setAccount(account);

  //const executionResponse = await programManager.run(
  //  program,
  //  aleoFunction,
  //  inputs,
  //  true,
  //);

  // Create execute options object
  const executeOptions = {
    programName: "price_proof_test_11.aleo",
    functionName: aleoFunction,
    priorityFee: 0,
    privateFee: false,
    inputs: inputs,
  };


  const transaction = await programManager.buildExecutionTransaction(
    executeOptions,
  );

  //var proof = transaction.execution().toString();
  var transaction_str = transaction.toString();

  console.log("transaction:", transaction_str);






  console.log("after programManager.buildExecutionTransaction");
  // loop through submitTransaction
  for (let i = 0; i < 50; i++) {
    try {
      console.log("in trial " + i);
      const tx = await programManager.networkClient.submitTransaction(
        transaction_str,
      );
      console.log("tx", tx);
      if (tx) {
        break;
      }
    }
    catch (e) {
      console.log("Error submitting transaction: ", e);
    }
  }
  console.log("after loop");




  //console.log("Execution response:", executionResponse);
  return [transaction_str];//executionResponse.getOutputs();
}

async function getPrivateKey() {
  const key = new PrivateKey();
  return proxy(key);
}

async function deployProgram(program, privateKey) {
  const keyProvider = new AleoKeyProvider();
  keyProvider.useCache(true);

  // Create a record provider that will be used to find records and transaction data for Aleo programs
  //const networkClient = new AleoNetworkClient("http://184.169.231.113:3030/");
  const networkClient = new AleoNetworkClient("https://api.explorer.provable.com/v1");
  //const networkClient = new AleoNetworkClient("http://127.0.0.1:3030");
  //const networkClient = new AleoNetworkClient("http://127.0.0.1:6000");
  //const networkClient = new AleoNetworkClient("https://explorer-middleware-prod-jake-provablecom-provablehq.vercel.app/v1");

  // Use existing account with funds
  const account = new Account({
    privateKey: privateKey,
    //privateKey: "APrivateKey1zkp8CZNn3yeCseEtxuVPbDCwSyhGW6yZKUYKfgXmcpoGPWH",
  });

  const recordProvider = new NetworkRecordProvider(account, networkClient);

  // Initialize a program manager to talk to the Aleo network with the configured key and record providers
  const programManager = new ProgramManager(
    //"http://184.169.231.113:3030/",
    "https://api.explorer.provable.com/v1",
    //"http://127.0.0.1:3030",
    //"http://127.0.0.1:6000",
    //"https://explorer-middleware-prod-jake-provablecom-provablehq.vercel.app/v1",
    keyProvider,
    recordProvider,
  );

  programManager.setAccount(account);

  // Define a fee to pay to deploy the program
  const fee = 1.9; // 1.9 Aleo credits

  // Deploy the program to the Aleo network
  console.log("before programManager.buildDeploymentTransaction");
  //const tx_id = await programManager.deploy(program, fee);
  const tx_id = await programManager.buildDeploymentTransaction(
    program,
    fee,
  );
  console.log("after programManager.buildDeploymentTransaction");
  console.log("tx_id", tx_id.toString());
  // loop through submitTransaction
  for (let i = 0; i < 50; i++) {
    try {
      console.log("in trial " + i);
      const tx = await programManager.networkClient.submitTransaction(
        tx_id.toString(),
        //account,
      );
      console.log("tx", tx);
      if (tx) {
        break;
      }
    }
    catch (e) {
      console.log("Error submitting transaction: ", e);
    }
  }
  console.log("after loop");

  // Optional: Pass in fee record manually to avoid long scan times
  // const feeRecord = "{  owner: aleo1xxx...xxx.private,  microcredits: 2000000u64.private,  _nonce: 123...789group.public}";
  // const tx_id = await programManager.deploy(program, fee, undefined, feeRecord);

  return tx_id;
}

const workerMethods = { localProgramExecution, getPrivateKey, deployProgram };
expose(workerMethods);
