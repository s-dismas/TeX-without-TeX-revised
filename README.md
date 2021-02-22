
## About

This is an update and expansion of TeX without TeX
(http://wiki.luatex.org/index.php/TeX_without_TeX) --- using TeX's
functionality (typesetting, pdf writing) using only Lua code (no \TeX
macros).

It is (I believe) an adequate framework for developing a complete
type-setting system; although one dedicated to a specific task, rather
than a general purpose system such as LaTeX or ConTeXt. It includes a
couple of example formatting commands (\Emph and \Bold), titles
(\Title), the ability to include other subsidiary text files (\Input)
and footnotes (\Footnote). It can be easily adapted and expanded to
suit your needs.

I am not much of a programmer, and knew little about TeX and even less
about Lua when I started this, so there is undoubtedly much that can
be improved.  All questions, comments, suggestions, and corrections
will be appreciated. You can reach me at "destiny6 <AT> mac <DOT>
com".

## Pre-requisites

This system requires the luatex-plain format (from ConTeXt), so that
we have access to Open Type Fonts and other goodies. This is what I
did on my system:

#### Find the luatex-plain.tex file. On my system (with TeX-Live 2020)
it was at: 

  ```
  /usr/local/share/texmf-dist/tex/generic/context/luatex/luatex-plain.tex
  ```

### If you just build a format file, 

  ```
  luatex --ini /usr/local/share/texmf-dist/tex/generic/context/luatex/luatex-plain.tex
  ``` 
  
  you will probably get warnings about using the "merged" file, and not
  the more current and supported files. Delete, move, or rename this
  file. On my system I did: 

  ```
  doas mv /usr/local/share/texmf-dist/tex/generic/context/luatex/luatex-fonts-merged.lua /usr/local/share/texmf-dist/tex/generic/context/luatex/luatex-fonts-merged.lua.bak
  ```

### Now, build the format file. 

  ```
  luatex --ini /usr/local/share/texmf-dist/tex/generic/context/luatex/luatex-plain.tex
  ```

### We are almost done. If the resulting format file (luatex-plain.fmt)
is in the current working directory, you can use it with something
like: 

  ```
  luatex --fmt luatex-plain test
  ```

### But, this is too restrictive.

  #### Create a new executable with the name luatex-plain. Something
  like: 

    ```
    ln -s `which luatex` /usr/local/bin/luatex-plain
    ```

  #### When you try to invoke it: 

    ```
    luatex-plain test
    ``` 

  it will fail with a message about failing to find the proper
  format file. There should be a line something like: 

    ```
    mktexfmt [INFO]: writing formats under ~/.texlive2020/texmf-var/web2c
    ``` 

  so, copy the format file to that location: 

    ```
    cp luatex-plain.fmt ~/.texlive2020/texmf-var/web2c/
    ``` 

  now, this should work: 

    ```
    luatex-plain test
    ``` 

    Finally, run mtxrun to generate a fonts database: 

    ```
    mtxrun --script fonts --reload --simple
    ```

