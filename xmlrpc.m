(* Mathematica Package         *)
(* Created by IntelliJ IDEA    *)

(* :Title: xmlrpc     *)
(* :Context: xmlrpc`  *)
(* :Author:
Paul-Jean Letournau, modified/packaged by Calle Ekdahl.
Original source: https://github.com/paul-jean/blog-this *)
(* :Date: 2015-07-28              *)

(* :Package Version: 1.0       *)
(* :Mathematica Version:       *)
(* :Keywords:                  *)
(* :Discussion:                *)

BeginPackage["wp`xmlrpc`"]

xmlrpcencode::usage = "xmlrpcencode[data] turns data into XML-RPC. Allowed data types are integers, reals, strings,\
 data encoded with base64 written as \"Base64\"[string], Hold[DateString[date]], vectors and structs. Vectors are\
 regular lists and structs are associations."

xmlrpcparse::usage = "xmlrpcparse[data] turns symbolic XML data representing XML-RPC into regular Mathematica lists. XML-RPC structs are of the form {key -> value, ...}."

Begin["`Private`"] (* Begin Private Context *)

xmlrpcencode[i_Integer] :=
    XMLElement["value", {}, {XMLElement["i4", {}, {ToString@i}]}]

xmlrpcencode[s_String] :=
    XMLElement["value", {}, {XMLElement["string", {}, {s}]}]

xmlrpcencode[r_Real] :=
    XMLElement["value", {}, {XMLElement["double", {}, {ToString@r}]}]

xmlrpcencode["Base64"[b64_String]] :=
    XMLElement["value", {}, {XMLElement["base64", {}, {b64}]}]

xmlrpcencode[bool : True | False] :=
    XMLElement[
      "value", {}, {XMLElement[
      "boolean", {}, {Replace[bool, {False -> "0", True -> "1"}]}]}]

xmlrpcencode[date : Hold[DateString[__]]] :=
    XMLElement[
      "value", {}, {XMLElement[
      "dateTime.iso8601", {}, {ReleaseHold@date}]}]

xmlrpcencode[struct_Association] :=
    XMLElement[
      "value", {}, {XMLElement["struct", {}, KeyValueMap[
      XMLElement[
        "member", {}, {XMLElement["name", {}, {#}],
        xmlrpcencode[#2]}] &, struct]]}]

xmlrpcencode[array : {___}] :=
    XMLElement[
      "value", {}, {XMLElement[
      "array", {}, {XMLElement["data", {}, xmlrpcencode /@ array]}]}]

xmlrpcencode[methodname_String, params_List] :=
    XMLObject["Document"][{},
      XMLElement[
        "methodCall", {}, {XMLElement["methodName", {}, {methodname}],
        XMLElement["params", {},
          XMLElement["param", {}, {xmlrpcencode@#}] & /@ params]}], {}]

xmlrpcparse[
  XMLObject["Document"][_,
    XMLElement[
      "methodResponse", {}, {XMLElement["params", {},
      params : {__XMLElement}]}], {}]] := xmlrpcparse /@ params

xmlrpcparse[
  XMLObject[
    "Document"][{XMLObject["Declaration"]["Version" -> "1.0", ___]},
    XMLElement[
      "methodResponse", {}, {XMLElement["fault", {},
      details : {__XMLElement}]}], {}]] := xmlrpcparse /@ details

xmlrpcparse[
  XMLElement[
    "param", {}, {value : XMLElement["value", {}, {__XMLElement}]}]] :=
    xmlrpcparse@value

xmlrpcparse[
  obj : XMLElement[
    "value", {}, {XMLElement[type_String, {}, val_]}]] := Block[{},
  Switch[{type, val},
    {"int" | "i4", {_String}}, ToExpression[First@val],
    {"double", {_String}}, ToExpression@First@val,
    {"string", {_String}}, First@val,
    {"dateTime.iso8601", {_String}}, First@val,
    {"boolean", {_String}},
    Replace[First@val, {"1" -> True, "0" -> False}],
    {"base64", {_String}}, ImportString[First@val, "Base64"],
    {"struct", {__XMLElement}}, xmlrpcparse[obj],
    {"array", {_XMLElement}}, xmlrpcparse[obj],
    {_, {}}, val
  ]
]

xmlrpcparse[
  XMLElement[
    "value", {}, {XMLElement["struct", {},
    members : {___XMLElement}]}]] :=
    Association @@ Cases[members,
      XMLElement[
        "member", {}, {XMLElement["name", {}, {name_String}],
        XMLElement["value", {}, {XMLElement[type_, {}, val_]}]}] :>
          name -> xmlrpcparse[
            XMLElement["value", {}, {XMLElement[type, {}, val]}]], {1}]

xmlrpcparse[
  XMLElement[
    "value", {}, {XMLElement[
    "array", {}, {XMLElement["data", {},
      values : {___XMLElement}]}]}]] :=
    Cases[values, XMLElement
    ["value", {}, {XMLElement[type_, {}, val_]}] :>
        xmlrpcparse[XMLElement
        ["value", {}, {XMLElement[type, {}, val]}]], {1}]

xmlrpcparse[___] := {$Failed}

End[]

EndPackage[]