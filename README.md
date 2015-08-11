# Wolfram Language WordPress XML-RPC Client

A Wolfram Language client for the [XML-RPC WordPress API](http://codex.wordpress.org/XML-RPC_WordPress_API).

GPL-2.0+ licensed.

Can be used in Wolfram Language packages or inside Mathematica. It works on Mathematica version 10 or higher.

## Usage

Only wp.m needs to be included in order to use the XML-RPC API as long as xmlrpc.m is in the same folder as wp.m it will also be included.

### Authentication

Each call made to WordPress' XML-RPC API needs to be authenticated by a username and a password. Conveniently, there is a mechanism for providing this information once such that it will be implicitly assumed in the following requests.

	SetCredentials["username", "password", endpoint]
	GetCredentials[]
	ClearCredentials[]

Use `SetCredentials` will store said credentials. You can use `? SetCredentials` to view the complete signature for that function (`Association` can also be used.) Use `GetCredentials[]` to view the currently used credentials, and use `ClearCredentials[]` to forget the credentials. `endpoint` is the URL to the the XML-RPC API server; usually it is will be of the form `http://example.com/xmlrpc.php`.

### API functions
Evaluate ``?wp`*`` in Mathematica to view the complete list of API functions. In order to inspect the signature of a specific function `? functionName` can be used. The signature includes the data type for each argument. Since the API mirrors the WordPress XML-RPC exactly, data types and arguments can also be read off of WordPress [online documentation](http://codex.wordpress.org/XML-RPC_WordPress_API). Even the names of functions in this API correspond to the names of the function in WordPress' API. Arguments of type array are represented by lists in Mathematica, and arguments of type struct are represented by Association. Thus, to use [`wp.getPost`](http://codex.wordpress.org/XML-RPC_WordPress_API/Posts) to retrieve the title, date, and content of all posts on the website, ordered by the post title, the following Wolfram Language code will do:

	getPosts[{"post_title", "post_date", "post_content"}, <|"orderby" -> "post_title"|>]

The list of elements to retrieve is known as `fields` in the WordPress documentation, and is explained there. The second argument is known as a `filter` in the WordPress documentation and is also explained there. This is pretty much everything you need to know to get started, because getting data always works like this. You can also create new a new post by passing an association with content and so on to `newPost`. You can even upload images or other media files to the media library, using `uploadFile`. The file has to be encoded as a base 64 string first, however. Example:

	data = "Base64"@ExportString[Import["~/Desktop/test.png", "String"], "Base64"];
	uploadFile[<|
      "name" -> "test.png",
      "type" -> "image/png",
      "bits" -> data
      |>]

Note that the data type for base 64 strings has the head `"base64"`.

### Callbacks
The package supports callbacks to simplify event-driven programming. To add a callback simply use `AddCallback[function]` and to remove all callbacks use `ClearCallbacks[]`. Events are fired whenever a function from the API is used, and can generate either success messages or failure messages:

    error[<|
        "event" -> "sending",
        "credentials" -> GetCredentials[],
        "method" -> method,
        "params" -> params,
        "responsexml" -> responsexml
        |>];

    success[<|
        "event" -> "sending",
        "credentials" -> GetCredentials[],
        "method" -> method,
        "params" -> params,
        "responsexml" -> responsexml
        |>];

Callback function can differentiate between error messages and success messages by their heads. Example:

	callback[success[event_]] := CreateDialog[{TextCell["Success!"], DefaultButton[]}];
	callback[error[event_]] := CreateDialog[{TextCell["Error!"], DefaultButton[]}];
