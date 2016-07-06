(* Mathematica Package         *)
(* Created by IntelliJ IDEA    *)

(* :Title: wp-notebook *)
(* :Context: wp-notebook` *)
(* :Author: Calle Ekdahl *)
(* :Date: 2016-07-06 *)

(* :Package Version: 1.0 *)
(* :Mathematica Version: 10.0 *)
(* :License: GPL-2.0+ *)
(* :Keywords:  WordPress, notebooks *)
(* :Discussion: Converts notebooks into suitable HTML and uploads it to WordPress. *)

BeginPackage["wpNotebookUpload`", {"wp`"}]

uploadNotebook::usage = "uploadNotebook[nb_String, fields_Association] creates a new post by converting the content of
the notebook with file path nb to WordPress suitable HTML. fields can be used to provide parameters such as post_type,
look up the XML-RPC newPost method in WordPress documentation for full information.\n
uploadNotebook[nb_String, id_Integer, fields_Association] works like the previous function excepts it updates an
existing post with ID id."

Begin["`Private`"] (* Begin Private Context *)

parseTextData::unrecognized = "An unsupported text element was ignored.";
parseCell::uninterpreted = "An unsupported type of cell was ignored.";
uploadGraphics::error = "Could not upload graphics to WordPress.";
convertNotebook::notebook = "Could not open the specified notebook."

hexifyColor[color_RGBColor] := StringJoin["#", IntegerString[Round[255 Level[color, 1]], 16, 2]]

parseCell[___][Cell[text_String, "Title", ___]] := StringJoin["<h1>", text, "</h1>"]
parseCell[___][Cell[text_String, "Subtitle", ___]] := StringJoin["<h2>", text, "</h2>"]
parseCell[___][Cell[text_String, "Subsubtitle", ___]] := StringJoin["<h3>", text, "</h3>"]
parseCell[___][Cell[text_String, "Section", ___]] := StringJoin["<h4>", text, "</h4>"]
parseCell[___][Cell[text_String, "Subsection", ___]] := StringJoin["<h5>", text, "</h5>"]
parseCell[___][Cell[text_String, "Subsubsection", ___]] := StringJoin["<h6>", text, "</h6>"]
parseCell[___][Cell[TextData[text_], "Text", ___]] := parseTextData[text]
parseCell[___][Cell[TextData[text_List], "Text", ___]] := StringJoin[parseTextData /@ text]
parseCell[___][gr : Cell[BoxData[_GraphicsBox], ___]] := uploadGraphics["notebook-graphics.png", gr]
parseCell[___][Cell[text_String, "Quote"]] := StringJoin["<blockquote>", text, "</blockquote>"]
parseCell[___][Cell[_, "HLine"]] := "<hr />"
parseCell[___][Cell[CellGroupData[cells_List, _]]] := parseCell /@ cells
parseCell[___][_] := (Message[parseCell::uninterpreted]; Null)

parseCell[opts: OptionsPattern[]][input : Cell[_BoxData, "Input", ___]] := StringJoin[
  OptionValue[convertNotebook, {opts}, "InputOpen"],
  First@FrontEndExecute[FrontEnd`ExportPacket[input, "InputText"]],
  OptionValue[convertNotebook, {opts}, "InputClose"]
]
parseCell[opts: OptionsPattern[]][output : Cell[_BoxData, "Output", ___]] := StringJoin[
  OptionValue[convertNotebook, {opts}, "OutputOpen"],
  First@FrontEndExecute[FrontEnd`ExportPacket[output, "InputText"]],
  OptionValue[convertNotebook, {opts}, "OutputClose"]
];

parseTextData[el_StyleBox] := Fold[addStyle, el]
parseTextData[ButtonBox[text_String, BaseStyle -> "Hyperlink", ButtonData -> {URL[url_String], ___}, ___]] := StringJoin[{"<a href=\"", url, "\">", text, "</a>"}]
parseTextData[el_String] := el
parseTextData[el_] := (Message[parseTextData::unrecognized]; Nothing[])

addStyle[text_String, FontWeight -> "Bold"] := StringJoin["<strong>", text, "</strong>"]
addStyle[text_String, FontSlant -> "Italic"] := StringJoin["<em>", text, "</em>"]
addStyle[text_String, FontVariations -> {"Underline" -> True}] := StringJoin["<span style=\"text-decoration: underline;\">", text, "</span>"]
addStyle[text_String, FontColor -> color_RGBColor] := StringJoin["<span style=\"color: ", hexifyColor[color], "\">", text, "</span>"]
addStyle[text_String, _] := text

uploadGraphics[fileName_, img_, maxWidth_: 650] := Module[{nb, uploadedImage},
      nb = CreateDocument[{}, WindowSelected -> False, Visible -> False, WindowSize -> maxWidth];
      NotebookWrite[nb, img];
      image = Rasterize[nb, "Image"];
      NotebookClose[nb];
      uploadedImage = uploadImage[fileName, image];
      If[uploadedImage === $Failed,
        Message[uploadGraphics::error]; $Failed,
        StringJoin["<img src=\"", uploadedImage["url"], "\" />"]
      ]
    ]

Options[convertNotebook] = {
  "InputOpen" -> "<pre><code>",
  "InputClose" -> "</code></pre>",
  "OutputOpen" -> "<pre><code>",
  "OutputClose" -> "</code></pre>"
}
convertNotebook[filePath_, opts: OptionsPattern[]] := With[{nb = NotebookOpen[filePath, Visible -> False]},
  If[nb === $Failed,
    Message[convertNotebook::notebook]; $Failed,
    Check[StringRiffle[parseCell[opts]@*NotebookRead /@ Cells[nb], "\n\n"], $Failed]
  ]
]

uploadNotebook[nb_String, fields_Association: <||>, opts: OptionsPattern[]] := With[{html = convertNotebook[nb, opts]},
  If[
    html === $Failed,
    $Failed,
    newPost[<|<|
        "post_type" -> "post",
        "post_title" -> "",
        "post_content" -> html,
        "post_status" -> "publish"
        |>, fields|>] // ToExpression
  ]
]

uploadNotebook[nb_String, id_Integer, fields_Association: <||>, opts: OptionsPattern[]] := Module[{html = convertNotebook[nb, opts]},
  If[
    html == $Failed,
    $Failed,
    editPost[id, <|<|
        "post_content" -> html
        |>, fields |>]
    ]
  ]

End[] (* End Private Context *)

EndPackage[]