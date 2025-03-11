const ProtectedInfo = {
  // generate here: https://tools.simonwillison.net/encrypt
  CONTENT:
    "BFf1F9GNAu58HL3L9v8t8aXIKsvnawmhlz2CMBAO56XAiHq8bhH+DGKimnZP/C2ED0YEu7Ilge279SNv9cFEWIqiRjSr02OFlirN9pCQERMayqU78ARGUlkBobR3IL7eqAIES+nIYN5yRjzc+NphLx+QklloHuKqMp6Atycz+up6hgIYAhcSzQ0Cv2CkCrEU8PS3iNjlW4Ziclk=",

  async generateKey(passphrase, salt) {
    // Convert passphrase to key material
    const encoder = new TextEncoder();
    const passphraseData = encoder.encode(passphrase);

    // Use PBKDF2 to derive a key from the passphrase
    const importedKey = await crypto.subtle.importKey("raw", passphraseData, { name: "PBKDF2" }, false, [
      "deriveBits",
      "deriveKey",
    ]);

    // Derive an AES-GCM key using PBKDF2
    return crypto.subtle.deriveKey(
      {
        name: "PBKDF2",
        salt: salt,
        iterations: 100000,
        hash: "SHA-256",
      },
      importedKey,
      { name: "AES-GCM", length: 256 },
      false,
      ["encrypt", "decrypt"]
    );
  },

  async decrypt(encryptedMessage, passphrase) {
    try {
      // Convert base64 back to Uint8Array
      const binaryString = atob(encryptedMessage);
      const bytes = new Uint8Array(binaryString.length);
      for (let i = 0; i < binaryString.length; i++) {
        bytes[i] = binaryString.charCodeAt(i);
      }

      // Extract salt, IV, and encrypted data
      const salt = bytes.slice(0, 16);
      const iv = bytes.slice(16, 28);
      const encryptedData = bytes.slice(28);

      // Generate decryption key from passphrase
      const key = await this.generateKey(passphrase, salt);

      // Decrypt the message
      const decryptedData = await crypto.subtle.decrypt({ name: "AES-GCM", iv }, key, encryptedData);

      // Convert decrypted data to string
      const decoder = new TextDecoder();
      return decoder.decode(decryptedData);
    } catch (error) {
      console.error("Decryption error:", error);
      throw new Error("Failed to decrypt the message. Wrong passphrase?");
    }
  },

  init() {
    const passwordForm = document.getElementById("password-form");
    const passwordInput = document.getElementById("password-input");
    const submitButton = document.getElementById("submit-password");
    const passwordError = document.getElementById("password-error");

    // Handle form submission
    const handleSubmit = async (event) => {
      if (event) event.preventDefault();

      const password = passwordInput.value.trim();
      if (!password) return;

      try {
        // Decrypt the content using the provided password
        const decryptedContent = await this.decrypt(this.CONTENT, password);

        // Replace the password form with the decrypted content
        passwordForm.innerHTML = decryptedContent;

        // Hide any previous error
        passwordError.classList.add("hidden");
      } catch (error) {
        // Show error message
        passwordError.classList.remove("hidden");
        passwordInput.value = "";
        passwordInput.focus();
      }
    };

    // Add event listeners
    submitButton.addEventListener("click", handleSubmit);
    passwordInput.addEventListener("keypress", (event) => {
      if (event.key === "Enter") {
        handleSubmit();
      }
    });
  },
};
