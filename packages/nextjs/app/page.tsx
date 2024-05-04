"use client";

import Link from "next/link";
import type { NextPage } from "next";
import { useAccount } from "wagmi";
import { BugAntIcon, MagnifyingGlassIcon, CakeIcon } from "@heroicons/react/24/outline";
import { Address } from "~~/components/scaffold-eth";
import { IDKitWidget, VerificationLevel, ISuccessResult } from '@worldcoin/idkit'

const handleVerify = async (proof: ISuccessResult) => {
  // const res = await fetch("/api/verify", { // route to your backend will depend on implementation
  //     method: "POST",
  //     headers: {
  //         "Content-Type": "application/json",
  //     },
  //     body: JSON.stringify(proof),
  // })
  // if (!res.ok) {
  //     throw new Error("Verification failed."); // IDKit will display the error message to the user in the modal
  // }
  console.log(proof);
};

const onSuccess = () => {
  // This is where you should perform any actions after the modal is closed
  // Such as redirecting the user to a new page
  // window.location.href = "/success";
  console.log("Success!");
};

const Home: NextPage = () => {
  const { address: connectedAddress } = useAccount();

  return (
    <>
      <div className="flex items-center flex-col flex-grow pt-10">
        <div className="px-5">
          <h1 className="text-center">
            <span className="block text-2xl mb-2">Welcome to</span>
            <span className="block text-4xl font-bold">Cache Coherence Wallet</span>
          </h1>
          <div className="flex justify-center items-center space-x-2">
            <p className="my-2 font-medium">Wallet Address:</p>
            <Address address={""} />
          </div>
          <div className="flex justify-center items-center mb-6 space-x-2">
            <p className="text-center text-lg">
              <button className="btn btn-primary mr-4">Deploy Wallet</button>
              <IDKitWidget
                app_id="app_staging_8e12a99bd10cac0f5e110ca03d0eaf21" // obtained from the Developer Portal
                action="test-recovery-action" // obtained from the Developer Portal
                signal={connectedAddress}
                onSuccess={onSuccess} // callback when the modal is closed
                handleVerify={handleVerify} // callback when the proof is received
                verification_level={VerificationLevel.Orb}
              >
                {({ open }) => 
                      // This is the button that will open the IDKit modal
                      <button onClick={open} className="btn btn-primary mr-4">Register World ID</button>
                  }
              </IDKitWidget>
              <button className="btn btn-primary mr-4">Recover Account</button>
            </p>
          </div>
        </div>
        <div className="flex-grow bg-base-300 w-full mt-16 px-8 py-12">
          <div className="flex justify-center items-center gap-12 flex-col sm:flex-row">
            <div className="flex flex-col bg-base-100 px-10 py-10 text-center items-center max-w-xs rounded-3xl">
              <BugAntIcon className="h-8 w-8 fill-secondary" />
              <p>
                Tinker with your smart contract using the{" "}
                <Link href="/debug" passHref className="link">
                  Debug Contracts
                </Link>{" "}
                tab.
              </p>
            </div>
            <div className="flex flex-col bg-base-100 px-10 py-10 text-center items-center max-w-xs rounded-3xl">
              <CakeIcon className="h-8 w-8 fill-secondary" />
              <p>
                Explore your local transactions with the{" "}
                <Link href="/blockexplorer" passHref className="link">
                  Block Explorer
                </Link>{" "}
                tab.
              </p>
            </div>
          </div>
        </div>
      </div>
    </>
  );
};

export default Home;
