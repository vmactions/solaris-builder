const core = require('@actions/core');
const exec = require('@actions/exec');
const tc = require('@actions/tool-cache');
const io = require('@actions/io');
const fs = require("fs");
const path = require("path");


async function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms))
}


async function vboxmanage(vmName, cmd, args = "") {
  await exec.exec("sudo  vboxmanage " + cmd + "   " + vmName + "   " + args);
}

async function pressF2(imgName) {
  await vboxmanage(imgName, "controlvm", "keyboardputscancode 3c bc");//Press F2
}

async function pressTAB(imgName) {
  await vboxmanage(imgName, "controlvm", "keyboardputscancode 0f 8f");//Press TAB
}

async function pressCtrlAltF2(imgName) {
  await vboxmanage(imgName, "controlvm", "keyboardputscancode 1d 38 3c bc b8 9d");//Press Ctrl + Alt + F2
}

async function getScreenText(vmName) {
  await vboxmanage(vmName, "controlvm", "screenshotpng  screen.png");
  await exec.exec("sudo chmod 666 screen.png");
  let output = "";
  await exec.exec("pytesseract  screen.png", [], {
    listeners: {
      stdout: (s) => {
        output += s;
      }
    }
  });
  return output;
}

async function waitFor(vmName, tag) {

  let slept = 0;
  while (true) {
    slept += 1;
    if (slept >= 300) {
      throw new Error("Timeout can not boot");
    }
    await sleep(1000);

    let output = await getScreenText(vmName);

    if (tag) {
      if (output.includes(tag)) {
        core.info("OK");
        await sleep(1000);
        return true;
      } else {
        core.info("Checking, please wait....");
      }
    } else {
      if (!output.trim()) {
        core.info("OK");
        return true;
      } else {
        core.info("Checking, please wait....");
      }
    }

  }

  return false;
}

// most @actions toolkit packages have async methods
async function run() {
  try {

    fs.appendFileSync(path.join(process.env["HOME"], "/.ssh/config"), "Host solaris " + "\n");
    fs.appendFileSync(path.join(process.env["HOME"], "/.ssh/config"), " User root" + "\n");
    fs.appendFileSync(path.join(process.env["HOME"], "/.ssh/config"), " HostName localhost" + "\n");
    fs.appendFileSync(path.join(process.env["HOME"], "/.ssh/config"), " Port 2222" + "\n");
    fs.appendFileSync(path.join(process.env["HOME"], "/.ssh/config"), "StrictHostKeyChecking=accept-new\n");


    if (process.env["DEBUG"]) {
      let sdk = "https://download.virtualbox.org/virtualbox/6.1.14/Oracle_VM_VirtualBox_Extension_Pack-6.1.14.vbox-extpack";
      core.info("Downloading sdk: " + sdk);
      let img = await tc.downloadTool(sdk);
      core.info("Downloaded file: " + img);
      await io.mv(img, "./Oracle_VM_VirtualBox_Extension_Pack-6.1.14.vbox-extpack");
      await exec.exec("sudo vboxmanage extpack install    --replace Oracle_VM_VirtualBox_Extension_Pack-6.1.14.vbox-extpack", [], { input: "y\n" });


      let ng = await tc.downloadTool("https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-darwin-amd64.zip");

      let token = process.env["NGROK_TOKEN"];
      await io.mv(ng, "./ngrok-stable-darwin-amd64.zip");
      await exec.exec("unzip -o ngrok-stable-darwin-amd64.zip");
      await exec.exec("./ngrok authtoken " + token);
      exec.exec("./ngrok  tcp   3390").catch((e) => {
        //
      });
    }


    core.info("Install tesseract");
    await exec.exec("brew install tesseract");
    await exec.exec("pip3 install pytesseract");


    let rootPassword = "vmactions.org";
    let imgName = "sol-11_4-vbox";
    let ova = imgName + ".ova";

    let part0 = "https://github.com/vmactions/solaris-download/releases/download/v0.0.1/sol-11_4-vbox.ova.zip";

    let part1 = "https://github.com/vmactions/solaris-download/releases/download/v0.0.1/sol-11_4-vbox.ova.z01";


    {
      core.info("Downloading image: " + part0);
      let img = await tc.downloadTool(part0);
      core.info("Downloaded file: " + img);
      await io.mv(img, "./" + ova + ".zip");

    }

    {
      core.info("Downloading image: " + part1);
      let img = await tc.downloadTool(part1);
      core.info("Downloaded file: " + img);
      await io.mv(img, "./" + ova + ".z01");

    }

    await exec.exec("7za e -y " + ova + ".zip");

    await vboxmanage("", "import", ova);

    await vboxmanage(imgName, "modifyvm", '--natpf1 "guestssh,tcp,,2222,,22"');


    await vboxmanage(imgName, "startvm", " --type headless");

    await waitFor(imgName, "System Configuration Tool enables you to specify the following");
    await sleep(1000);
    await pressF2(imgName);//Press F2


    //computer name
    await waitFor(imgName, "Enter a name for this computer that identifies it on the network");
    await sleep(1000);
    await vboxmanage(imgName, "controlvm", "keyboardputstring  solaris");
    await sleep(1000);
    await pressF2(imgName);//Press F2


    //wire net0
    await waitFor(imgName, "Select a wired network connection to configure");
    await sleep(1000);
    await pressF2(imgName);//Press F2

    //dhcp
    await waitFor(imgName, "Select how the network interface should be configured");
    await sleep(1000);
    await pressF2(imgName);//Press F2


    //Select timezone
    await waitFor(imgName, "Select the region that contains your time zone.");
    await sleep(1000);
    await pressF2(imgName);//Press F2

    //Select language
    await waitFor(imgName, "Select the default language support and locale specific data format");
    await sleep(1000);
    await pressF2(imgName);//Press F2

    //set date
    await waitFor(imgName, "Edit the date and time as necessary");
    await sleep(1000);
    await pressF2(imgName);//Press F2


    //select keyboard
    await waitFor(imgName, "Select your keyboard.");
    await sleep(1000);
    await pressF2(imgName);//Press F2


    //set root password
    await waitFor(imgName, "Define a root password for the system and user account for yourself.");
    await sleep(1000);

    await vboxmanage(imgName, "controlvm", "keyboardputstring  " + rootPassword);
    await sleep(1000);

    await pressTAB(imgName);
    await sleep(1000);

    await vboxmanage(imgName, "controlvm", "keyboardputstring  " + rootPassword);
    await sleep(1000);

    await pressF2(imgName);//Press F2


    //select Oracle Support credentials
    await waitFor(imgName, "Provide your My Oracle Support credentials to be informed");
    await sleep(1000);
    await pressF2(imgName);//Press F2

    //Review the settings below before continuing
    await waitFor(imgName, "Review the settings below before continuing. Go back (F3) to make");
    await sleep(1000);
    await pressF2(imgName);//Press F2




    //check booting
    await waitFor(imgName, "Booting to milestone");
    await waitFor(imgName, "Hostname: solaris");
    await waitFor(imgName, "solaris console login:");
    await waitFor(imgName, "");
    await sleep(1000);

    while (true) {
      await pressCtrlAltF2(imgName);
      await sleep(1000);
      let text = await getScreenText(imgName);
      if (text.includes("oo E eR aA Sera |")) {
        break;
      }
    }

    await vboxmanage(imgName, "controlvm", "keyboardputfile  enablessh.txt");
    core.info("setup ssh finished");
    let sshkey = "";
    await exec.exec("ssh solaris", [], {
      input: 'cat ~/.ssh/id_rsa.pub', listeners: {
        stdout: (s) => {
          sshkey += s;
        }
      }
    });

    core.info("sshkey:" + sshkey);

    fs.writeFileSync(__dirname + "/id_rsa.pub", sshkey);

    core.info("Power off");
    await exec.exec("ssh solaris", [], { input: 'shutdown -y -i5 -g0' });

    while (true) {
      core.info("Sleep 2 seconds");
      await sleep(2000);
      let std = "";
      await exec.exec("sudo vboxmanage list runningvms", [], {
        listeners: {
          stdout: (s) => {
            std += s;
            core.info(s);
          }
        }
      });
      if (!std) {
        core.info("shutdown OK continue.");
        await sleep(2000);
        break;
      }
    }

    core.info("Export " + ova);
    await io.rmRF(ova);
    await vboxmanage(imgName, "export", "--output " + ova);
    await exec.exec("sudo chmod 666 " + ova);

    core.info("Split file");
    await io.rmRF(ova + ".zip");
    await exec.exec("zip -0 -s 2000m " + ova + ".zip " + ova + " id_rsa.pub");
    await exec.exec("ls -lah");

  } catch (error) {
    core.setFailed(error.message);
  } finally {
    if (process.env["DEBUG"]) {
      await exec.exec("killall -9 ngrok", [], { ignoreReturnCode: true });
    }
  }
}

run();
