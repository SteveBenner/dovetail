require "openssl"
require "base64"
require_relative "canonical_json"

module Dovetail
  module Signing
    module_function

    def sign(shape_hash, private_key_pem)
      key = OpenSSL::PKey::RSA.new(private_key_pem)
      digest = OpenSSL::Digest.new("SHA256")
      message = Dovetail::CanonicalJSON.dump(shape_hash)
      signature = key.sign_pss(digest, message, salt_length: :digest, mgf1_hash: "SHA256")
      Base64.strict_encode64(signature)
    end

    def verify(shape_hash, signature_b64, public_key_pems)
      message = Dovetail::CanonicalJSON.dump(shape_hash)
      signature = Base64.strict_decode64(signature_b64)
      digest = OpenSSL::Digest.new("SHA256")
      Array(public_key_pems).each do |pem|
        begin
          key = OpenSSL::PKey::RSA.new(pem)
          return :ok if key.verify_pss(digest, signature, message, salt_length: :digest, mgf1_hash: "SHA256")
        rescue OpenSSL::PKey::PKeyError
          next
        end
      end
      :bad_signature
    rescue ArgumentError
      :bad_signature
    end

    def signature_path(shape_path)
      shape_path.sub(/\.json\z/, ".sig")
    end
  end
end
