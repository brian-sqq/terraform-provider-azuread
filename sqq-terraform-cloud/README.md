## Publishing Provider for Terraform Cloud
Follow instructions in this [documentation](https://developer.hashicorp.com/terraform/cloud-docs/registry/publish-providers).

### [Create the provider](https://developer.hashicorp.com/terraform/cloud-docs/registry/publish-providers#create-the-provider)
We have added the `provider.json` file here, but have already used the API to create the provider.

It's required to sign the build, and upload the signature's public key to Terraform Cloud.

> Make sure you have `gnupg` and `jq` installed in order to use the subsequent commands.

#### Generate a GPG Key
Run the following, choosing RSA for type, and 4096 for size.

```sh
gpg --full-generate-key
```

Then, get your key id like this.

```sh
gpg --list-secret-keys --keyid-format=long
```

Then, copy the value in the `sec` line after `rsa4096/`.  This is your long key id.  Set it as an environment variable.

```sh
export GPG_KEY_ID="your long key id"
```

#### Build Your Binary
With your `GPG_KEY_ID` environment variable, you are ready to build the provider binary and associated distribution artifacts.  There's a helper script here to make this easy to build for linux/amd64.

First, decide the version you want to name the published provider, for example `3.5.0-sqq.1`.  Run the script with that version as the argument.

> If you set a passphrase for your GPG Key, make sure to pay attention for the prompt after you kick off this script!

```sh
./scripts/package-provider.sh 3.5.0-sqq.1
```

This produces everything you need for the steps _after_ __Add your public key__.

### [Add your public key](https://developer.hashicorp.com/terraform/cloud-docs/registry/publish-providers#add-your-public-key)

Use your `GPG_KEY_ID` environment variable to create your raw `public.asc`.

```sh
gpg --armor --export $GPG_KEY_ID > public.asc
```

Use your raw `public.asc` to create a formatted value for the `key.json` file.

```sh
jq -n --arg ns SuperQuickQuestion --rawfile key public.asc \               
'{
  data:{
    type:"gpg-keys",
    attributes:{
      namespace:$ns,
      "ascii-armor":$key
    }
  }
}' > key.json
```

Follow the remaining steps in the documentation for this section to upload the key, and __copy the response's `key-id`.

### [Create a version](https://developer.hashicorp.com/terraform/cloud-docs/registry/publish-providers#create-a-version)
Using the version you created and the `key-id` you copied from the previous step, follow instructions in this section of the documentation.  Be sure to __copy the 2 `links` outputs for the next step`__.

### [Upload signatures](https://developer.hashicorp.com/terraform/cloud-docs/registry/publish-providers#upload-signatures)
Using the `links` URL's from the response in the previous step, follow instructions in this section of the documentation.

### [Create the provider platform]()
Follow the instructions in this section of the documentation.  Be sure to __copy the `links.provider-binary-upload` output for the next step__.

__NOTE__
There's a strange hardcoded path in the URL of the curl command.  I updated it in my call to match our provider and version.  See here.

```sh
curl \
  --header "Authorization: Bearer $TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  --request POST \
  --data @platform.json \
  https://app.terraform.io/api/v2/organizations/SuperQuickQuestion/registry-providers/private/SuperQuickQuestion/azuread/versions/3.5.0-sqq.1/platforms
```

### [Upload provider binary](https://developer.hashicorp.com/terraform/cloud-docs/registry/publish-providers#upload-provider-binary)
Using the `links.provider-binary-upload` URL from the previous step, follow instructions in this section of the documentation.