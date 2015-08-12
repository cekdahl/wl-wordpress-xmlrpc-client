(* Mathematica Package         *)
(* Created with IntelliJ IDEA    *)

(* :Title: WordPress XML-RPC Wolfram Language Client *)
(* :Context: wp`  *)
(* :Author: Calle Ekdahl *)
(* :Date: 2015-07-28 *)

(* :Package Version: 1.0 *)
(* :Mathematica Version: 10.0 *)
(* :License: GPL-2.0+ *)
(* :Keywords: XML-RPC, WordPress *)
(* :Discussion: The API exactly mirrors WordPress' XML-RPC API. Structs are represented by Association, arrays
are represented by List. WordPress documentation of the various XML-RPC API functions can be found here:
http://codex.wordpress.org/XML-RPC_WordPress_API

The getPostyType fields parameter does not work like the fields parameter in other API calls,
but that's a problem with WordPress and not this XML-RPC client. Similarly setOptions does not appear to work at
all, but again will submit the correct XML-RPC to WordPress. At least for the current version of WordPress, v4.2.3,
I would not use this function. I'll leave it in because things may change. *)

BeginPackage["wp`", {"xmlrpc`"}]

AddCallback::usage = "AddCallback[method] adds a callback to the list of callbacks.";
ClearCallbacks::usage = "ClearCallbacks[] empties the list of callbacks.";

SetCredentials::usage = "SetCredentials[username_String, password_String, endpoint_String, blogID_Integer: 1]
SetCredentials[c_Association] can be used to set or update credentials selectively. Use keys username, passsword, endpoint, and blogID.";
GetCredentials::usage = "GetCredentials[]";
ClearCredentials::usage = "ClearCredentials[]";

getPost::usage = "getPost[postID_Integer]\ngetPost[postID_Integer, fields_List]";
getPosts::usage = "getPosts[]\ngetPosts[fields_List, filter_Association: <||>]";
newPost::usage = "newPost[content_Association]";
editPost::usage = "editPost[postID_Integer, content_Association]";
deletePost::usage = "deletePost[postID_Integer]";
getPostType::usage ="getPostType[postTypeName_String]\ngetPostType[postTypeName_String, fields_List]";
getPostTypes::usage = "getPostTypes[filter_Association: <||>]\ngetPostTypes[filter_Association, fields_List]";
getPostFormats::usage = "getPostFormats[filter_Association: <||>]";
getPostStatusList::usage = "getPostStatusList[]"

getTaxonomy::usage = "getTaxonomy[taxonomy_String]";
getTaxonomies::usage = "getTaxonomies[]";
getTerm::usage = "getTerm[taxonomy_String, termID_Integer]";
getTerms::usage = "getTerms[taxonomy_String, filter_Association: <||>]";
newTerm::usage = "newTerm[content_Association]";
editTerm::usage = "editTerm[termID_Integer, content_Association]";
deleteTerm::usage = "deleteTerm[taxonomy_String, termID_Integer]";

getMediaItem::usage = "getMediaItem[attachmentID_Integer]";
getMediaLibrary::usage = "getMediaLibrary[filter_Association: <||>]";
uploadFile::usage = "uploadFile[data_Association]";

getCommentCount::usage ="getCommentCount[postID_Integer]";
getComment::usage = "getComment[commentID_Integer]";
getComments::usage = "getComments[filter_Association: <||>]";
newComment::usage = "newComment[postID_Integer, comment_Association]";
editComment::usage = "editComment[commentID_Integer, comment_Association]";
deleteComment::usage = "deleteComment[commentID_Integer]";
getCommentStatusList::usage = "getCommentStatusList[]";

getOptions::usage = "getOptions[options_List]";
setOptions::usage = "setOptions[options_Association]";

getUsersBlog::usage = "getUsersBlogs[]";
getUser::usage = "getUser[userID_Integer, fields_List: {}]";
getUsers::usage = "getUsers[filter_Association: <||>, fields_List: {}]";
getProfile::usage = "getProfile[fields_List: {}]";
editProfile::usage = "editProfile[content_Association]";
getAuthors::usage = "getAuthors[]";

SendRequest::usage = "SendRequest[method_, params_] Sends a general request using the configured credentials and endpoint."

Begin["`Private`"] (* Begin Private Context *)

username = "";
password = "";
endpoint = "";
blogID = 1;

callbacks = {};

AddCallback[method_] := AppendTo[callbacks, method]
ClearCallbacks[] := callbacks = {}

SetCredentials[u_String, p_String, e_String, bID_Integer: 1] := (
  username = u;
  password = p;
  endpoint = e;
  blogID = bID;
)

SetCredentials[c_Association] := (
  If[MatchQ[c["username"], _String], username = c["username"]];
  If[MatchQ[c["password"], _String], password = c["password"]];
  If[MatchQ[c["endpoint"], _String], endpoint = c["endpoint"]];
  If[MatchQ[c["blogID"], _Integer], blogID = c["blogID"]];
)

GetCredentials[] := <|
      "username" -> username,
      "password" -> password,
      "endpoint" -> endpoint,
      "blogID" -> blogID
    |>

ClearCredentials[] := (
  username = "";
  password = "";
  endpoint = "";
)

SendRequest::credentials = "Credentials username, password and endpoint must have string values. blogID must be an integer.";
SendRequest::failed = "`1`";

SendRequest[method_, params_] := Module[{event, payload, responsexml},

  payload = ExportString[xmlrpcencode[method, params], "XML"];

  responsexml = Quiet@Check[URLFetch[
    endpoint,
    "Body" -> payload,
    "Method" -> "POST"
  ], Return[$Failed]];

  responsexml = Quiet@Check[ImportString[responsexml, "XML"], Return[$False]];
  responsexml = With[{res = First@xmlrpcparse[responsexml]},
    If[res === $Failed, Return[$Failed], res]
  ];

  If[
    AssociationQ[responsexml] && KeyExistsQ[responsexml, "faultString"],
    Message[SendRequest::failed, responsexml["faultString"]];

    event = Global`error[<|
        "event" -> "response",
        "credentials" -> GetCredentials[],
        "method" -> method,
        "params" -> params,
        "responsexml" -> responsexml
        |>];

    Through[callbacks[event]];

    $Failed,

    event = Global`success[<|
        "event" -> "response",
        "credentials" -> GetCredentials[],
        "method" -> method,
        "params" -> params,
        "responsexml" -> responsexml
        |>];

    Through[callbacks[event]];

    responsexml
  ]

]

(* API signatures *)
getPost[postID_Integer] := SendRequest["wp.getPost", {blogID, username, password, postID}]
getPost[postID_Integer, fields_List] := SendRequest["wp.getPost", {blogID, username, password, postID, fields}]
getPosts[] := SendRequest["wp.getPosts", {blogID, username, password}]
getPosts[fields_List, filter_Association: <||>] := SendRequest["wp.getPosts", {blogID, username, password, filter, fields}]
newPost[content_Association] := SendRequest["wp.newPost", {blogID, username, password, content}]
editPost[postID_Integer, content_Association] := SendRequest["wp.editPost", {blogID, username, password, postID, content}]
deletePost[postID_Integer] := SendRequest["wp.deletePost", {blogID, username, password, postID}]
getPostType[postTypeName_String] := SendRequest["wp.getPostType", {blogID, username, password, postTypeName}]
getPostType[postTypeName_String, fields_List] := SendRequest["wp.getPostType", {blogID, username, password, postTypeName, fields}]
getPostTypes[filter_Association: <||>] := SendRequest["wp.getPostTypes", {blogID, username, password, filter}]
getPostTypes[filter_Association, fields_List] := SendRequest["wp.getPostTypes", {blogID, username, password, filter, fields}]
getPostFormats[filter_Association: <||>] := SendRequest["wp.getPostFormats", {blogID, username, password, filter}]
getPostStatusList[] := SendRequest["wp.getPostStatusList", {blogID, username, password}]

getTaxonomy[taxonomy_String] := SendRequest["wp.getTaxonomy", {blogID, username, password, taxonomy}]
getTaxonomies[] := SendRequest["wp.getTaxonomies", {blogID, username, password}]
getTerm[taxonomy_String, termID_Integer] := SendRequest["wp.getTerm", {blogID, username, password, taxonomy, termID}]
getTerms[taxonomy_String, filter_Association: <||>] := SendRequest["wp.getTerms", {blogID, username, password, taxonomy, filter}]
newTerm[content_Association] := SendRequest["wp.newTerm", {blogID, username, password, content}]
editTerm[termID_Integer, content_Association] := SendRequest["wp.editTerm", {blogID, username, password, termID, content}]
deleteTerm[taxonomy_String, termID_Integer] := SendRequest["wp.deleteTerm", {blogID, username, password, taxonomy, termID}]

getMediaItem[attachmentID_Integer] := SendRequest["wp.getMediaItem", {blogID, username, password, attachmentID}]
getMediaLibrary[filter_Association: <||>] := SendRequest["wp.getMediaLibrary", {blogID, username, password, filter}]
uploadFile[data_Association] := SendRequest["wp.uploadFile", {blogID, username, password, data}]

getCommentCount[postID_Integer] := SendRequest["wp.getCommentCount", {blogID, username, password, postID}]
getComment[commentID_Integer] := SendRequest["wp.getComment", {blogID, username, password, commentID}]
getComments[filter_Association: <||>] := SendRequest["wp.getComments", {blogID, username, password, filter}]
newComment[postID_Integer, comment_Association] := SendRequest["wp.newComment", {blogID, username, password, postID, comment}]
editComment[commentID_Integer, comment_Association] := SendRequest["wp.editComment", {blogID, username, password, commentID, comment}]
deleteComment[commentID_Integer] := SendRequest["wp.deleteComment", {blogID, username, password, commentID}]
getCommentStatusList[] := SendRequest["wp.getCommentStatusList", {blogID, username, password}]

getOptions[options_List] := SendRequest["wp.getOptions", {blogID, username, password, options}]
setOptions[options_] := SendRequest["wp.setOptions", {blogID, username, password, options}]

getUsersBlog[] := SendRequest["wp.getUsersBlogs", {username, password}]
getUser[userID_Integer] := SendRequest["wp.getUser", {blogID, username, password, userID}]
getUser[userID_Integer, fields_List] := SendRequest["wp.getUser", {blogID, username, password, userID, fields}]
getUsers[filter_Association: <||>] := SendRequest["wp.getUsers", {blogID, username, password, filter}]
getUsers[filter_Association, fields_List] := SendRequest["wp.getUsers", {blogID, username, password, filter, fields}]
getProfile[] := SendRequest["wp.getProfile", {blogID, username, password}]
getProfile[fields_List] := SendRequest["wp.getProfile", {blogID, username, password, fields}]
editProfile[content_Association] := SendRequest["wp.editProfile", {blogID, username, password, content}]
getAuthors[] := SendRequest["wp.getAuthors", {blogID, username, password}]

End[] (* End Private Context *)

EndPackage[]