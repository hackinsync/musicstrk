import React from 'react';
import Image from 'next/image';
import argent from '../app/assets/images/argent.png';
import braavos from '../app/assets/images/braavos.png';

interface ConnectWalletModalProps {
    isOpen: boolean;
    onClose: () => void;
}

const ConnectWalletModal: React.FC<ConnectWalletModalProps> = ({ isOpen, onClose }) => {
    if (!isOpen) return null;

    return (
        <div className="fixed inset-0 flex items-center justify-center bg-black bg-opacity-70">
            <div className="bg-gray-800 p-6 rounded-lg shadow-lg w-96 relative">
                <button 
                    className="absolute top-2 right-2 text-gray-400 hover:text-white text-2xl"
                    onClick={onClose}
                >
                    &times;
                </button>
                
                <h3 className="text-lg text-blue-400 mb-2">Sign in</h3>
                <p className="text-gray-300 mb-4">Connect your StarkNet wallet to access your account</p>
                
                <p className="mb-2 text-gray-200">Choose a wallet to connect:</p>
                <div className="grid grid-cols-2 gap-4 mb-4">
                    <button className="flex h-24 flex-col items-center justify-center gap-2 border-blue-800 bg-[#111a2f] p-4 text-blue-300 hover:bg-[#1a2747] hover:text-blue-200">
                        <Image 
                            src={argent} 
                            alt="Argent" 
                            className="mb-2" 
                            width={24}
                            height={24}
                        />
                        Argent
                    </button>
                    <button className="flex h-24 flex-col items-center justify-center gap-2 border-blue-800 bg-[#111a2f] p-4 text-blue-300 hover:bg-[#1a2747] hover:text-blue-200">
                        <Image 
                            src={braavos} 
                            alt="Braavos"  
                            width={48}
                            height={48}
                        />
                        Braavos
                    </button>
                </div>

                <p className="text-center text-gray-400 mb-2">OR</p>
                <button className="bg-blue-500 text-white px-4 py-2 rounded w-full mb-4" onClick={onClose}>
                    Connect another wallet
                </button>

                <p className="text-xs text-center text-gray-500 mt-4">
                    By connecting your wallet, you agree to our Terms of Service and Privacy Policy.
                </p>
            </div>
        </div>
    );
};

export default ConnectWalletModal;