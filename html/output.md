```mermaid
graph TD
    n0[Document]
    n0 --> n1
    n1[html]
    n1 --> n2
    n2[head]
    n2 --> n3
    n3[meta]
    n2 --> n4
    n4[meta]
    n2 --> n5
    n5[title]
    n5 --> n6
    n6["Document"]
    n2 --> n7
    n7[style]
    n7 --> n8
    n8["
        .container {
            width: 100%;
            height: 100px;
            background-color: lightblue;
            border: 1px solid blue;
        }
    "]
    n1 --> n9
    n9[body]
    n9 --> n10
    n10[h1]
    n10 --> n11
    n11["Test File"]
    n9 --> n12
    n12[p]
    n12 --> n13
    n13["This is a test file to check the functionality of the HTML structure."]
    n9 --> n14
    n14[div]
    n14 --> n15
    n15[p]
    n15 --> n16
    n16["Container div for layout purposes."]
    n14 --> n17
    n17[img]
    n14 --> n18
    n18[input]
    n9 --> n19
    n19[comment: "<!-- This is a single line comment -->"]
    n9 --> n20
    n20[comment: "<!-- 
    This is a multi-line comment
    that spans multiple lines.
     -->"]
    n9 --> n21
    n21[comment: "<!-- 
    This comment includes tags
    <div>Some HTML</div>
    <p>Some text</p> 
    -->"]
    n9 --> n22
    n22[script]
    n22 --> n23
    n23["
        // This is a single line JavaScript comment
        console.log("Hello, World!");

        /*
        This is a multi-line JavaScript comment
        that can span multiple lines.
        */
        // This is a comment with HTML tags
        console.log("<div>Some HTML</div>");
        // This is a comment with HTML tags
    "]
    n9 --> n24
    n24[script]
    n24 --> n25
    n25[""]
```
