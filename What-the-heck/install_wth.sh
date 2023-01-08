# install.sh
# (c) Joerg Meyer, 2023-01-08

echo "Installing wth files and alias function"

WTHPATH="/usr/local/share/wth"

if [ -d $WTHPATH ]
then
    echo "Folder already exists."
else
    sudo mkdir -p $WTHPATH
    echo "Target folder created."
fi

sudo unzip wth.zip -d $WTHPATH
echo "Files with abbreviations moved to target folder."

cat >> ~/.bashrc <<end-of-function

wth() {
    if [ -z "\$1" ]
    then
        echo "wth: No abbreviation to look up"
    else
	grep -ia "^\$1 " $WTHPATH/* | cut -c $((${#WTHPATH}+2))-
    fi
}
end-of-function
echo "wth placed into .bashrc as function definition."

echo "Done."
