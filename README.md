# Wolfram Language WordPress XML-RPC Client

A Wolfram Language client for the [XML-RPC WordPress API](http://codex.wordpress.org/XML-RPC_WordPress_API).

GPL-2.0+ licensed.

Can be used in Wolfram Language packages or inside Mathematica. It works on Mathematica version 11.2 or higher.

## Change log

**28/10/2018:** A new package, `wpPalette`, provides a palette that uses `wpNotebookUpload` to upload notebooks to WordPress. It is now possible to post copyable code images, as seen on [wolframlanguagereviews.org](wolframlanguagereviews.org). The article [Posting notebooks to WordPress](http://wolframlanguagereviews.org/2018/10/28/posting-notebooks-to-wordpress/) gives a detailed description of what the package does.

**6/7/2016**: New high-level function, `imageUpload`, for `wp` and a new package, `wpNotebookUpload`, for posting notebooks to WordPress. In addition, [Mathematica Toolbox](https://wordpress.org/plugins/mathematica-toolbox/) users get the new `getCustomField` and `setCustomField` functions. Slight name changes for callback and credentials related functions.

**12/8/2015**: First release, including only `xmlrpc` and `wp`.

## Usage

Only wp.m needs to be included in order to use the XML-RPC API, as long as xmlrpc.m is in the same folder as wp.m it will also be included.

### Authentication

Each call made to WordPress' XML-RPC API needs to be authenticated by a username and a password. Conveniently, there is a mechanism for providing this information once such that it will be used in the following requests.

	SetWordPressCredentials["username", "password", endpoint]
	GetWordPressCredentials[]
	ClearWordPressCredentials[]

`SetCredentials` will store said credentials. You can use `?SetCredentials` to view the complete signature for that function (`Association` can also be used.) Use `GetCredentials[]` to view the currently used credentials, and use `ClearCredentials[]` to forget the credentials. `endpoint` is the URL to the the XML-RPC API server; usually it will be of the form `http://example.com/xmlrpc.php`.

### API functions
Evaluate ``?wp`*`` in Mathematica to view the complete list of API functions. In order to inspect the signature of a specific function `?functionName` can be used. The signature includes the data type for each argument. Since the API mirrors the WordPress XML-RPC exactly, data types and arguments can also be read off of WordPress [online documentation](http://codex.wordpress.org/XML-RPC_WordPress_API). Even the names of functions in the Wolfram Language API correspond to the names of the function in WordPress' API. Arguments of type array are represented by lists in Wolfram Language, and arguments of type struct are represented by Association. Thus, to use [`wp.getPost`](http://codex.wordpress.org/XML-RPC_WordPress_API/Posts) to retrieve the title, date, and content of all posts on the website, ordered by the post title, the following Wolfram Language code will do:

	getPosts[{"post_title", "post_date", "post_content"}, <|"orderby" -> "post_title"|>]

The list of elements to retrieve is known as `fields` in the WordPress documentation, and is explained there. The second argument is known as a `filter` in the WordPress documentation and is also explained there; note that the data types is array and struct respectively according to the documentation. Getting data always works like this. You can also create new a new post by passing an association with content and so on to `newPost`. You can even upload images or other media files to the media library by using `uploadFile`. The file has to be encoded as a base 64 string first, however. Example:

	data = "Base64"@ExportString[Import["~/Desktop/test.png", "String"], "Base64"];
	uploadFile[<|
      "name" -> "test.png",
      "type" -> "image/png",
      "bits" -> data
      |>]

Note that the data type for base 64 strings has the head `"base64"`.

### Callbacks
The package supports callbacks to simplify event-driven programming. To add a callback simply use `AddWordPressCallback[function]` and to remove all callbacks use `ClearWordPressCallbacks[]`. Events are fired whenever a function from the API is used, and can generate either success messages or failure messages:

    error[<|
        "event" -> "response",
        "credentials" -> GetWordPressCredentials[],
        "method" -> method,
        "params" -> params,
        "responsexml" -> responsexml
        |>];

    success[<|
        "event" -> "response",
        "credentials" -> GetWordPressCredentials[],
        "method" -> method,
        "params" -> params,
        "responsexml" -> responsexml
        |>];

Callback function can differentiate between error messages and success messages by their heads. Example:

	callback[success[event_]] := CreateDialog[{TextCell["Success!"], DefaultButton[]}];
	callback[error[event_]] := CreateDialog[{TextCell["Error!"], DefaultButton[]}];
	
### Custom XML-RPC calls
WordPress does not provide a way to get or set custom fields via XML-RPC by default. The WordPress plugin [Mathematica Toolbox](https://wordpress.org/plugins/mathematica-toolbox/) extends the XML-RPC API to make it possible. Therefore, if and only if your blog has this plugin installed, you can use `getCustomField[postID_Integer, fieldName_String]` and `setCustomField[postID_Integer, fieldName_String, fieldValue_]` to get and set custom field.

## wpNotebookUpload
A package called wpNotebookUpload is bundled with the XML-RPC client. Given the file path to a Mathematica notebook it can convert the content of the notebook into the same HTML that WordPress WYSIWYG editor would generate, and upload it to WordPress. It can be used to either create new posts and pages, or to overwrite existing ones. The commands are

    uploadNotebook[nb_String, fields_Association: <||>, opts: OptionsPattern[]]
    uploadNotebook[nb_String, id_Integer, fields_Association: <||>, opts: OptionsPattern[]]
    
where in the second command `id` is the id of the post to update. `fields` can be used to set the same properties as `newPost` and `editPost`. The options can be used to decide what tag to use to surround input and output code blocks with. By default it's just `<pre><code>code here</pre></code>` but if you have the plugin [Mathematica Toolbox](https://wordpress.org/plugins/mathematica-toolbox/) installed then you'll want perhaps to use

    uploadNotebook[
     "/path/to/notebook.nb",
     "InputOpen" -> "[wlcode]",
     "InputClose" -> "[/wlcode]"
     ]
     
to get syntax highlighting. Similarly you can use `OutputOpen` and `OutputClose` to wrap output code. Here is a list of things `uploadNotebook` will do:

 - Images in output will be uploaded and inserted.
 - Title, subtitle, subsubtitle, section, subsection, subsubsection will be mapped to h1, h2, h3, h4, h5, h6.
 - Colored, bold, italic, underlined text works.
 - Links work.
 - Code in input cells and code in output cells will be insert wrapped according to what is said above.

This covers the main features of WordPress' editor's toolbar. There is no intention of adding, say, font or font size because it is the responsibility of the WordPress theme designer to make decisions about such things. Note that if a notebook uses features that are not supported then it will not be uploaded.

## wpPalette
When installing the paclet, a new palette will appear in the Palettes menu in Mathematica, thanks to the `wpPalette` package. A detailed description of what the package does, with screenshots, is available in the form of an article at Wolfram Language Reviews, [Posting notebooks to WordPress](http://wolframlanguagereviews.org/2018/10/28/posting-notebooks-to-wordpress/).