So you want your work to be included in Dabdoob? You came to the right file!

Hello! I am honored to have you here, as I am always looking to include more content in my launcher, to apply you will need to reach out to me. Which you can do on TLG's Discord (https://discord.com/invite/zT9sXmZNCK) or by submitting an issue here on the github. We have some minimal requirements to make sure that your work is functional and not broken. Please read the part related to the type of work you made below to understand the process and requirements

Note: For Tilesets and Soundpacks, anyone can make a request. For mods, you need to be someone working on the mod


## Mods:
To apply, please provide a description of your mod with the link to the github repo. The earliest working release must be at least 2 weeks old and you have to confirm that it's working for the supported forks. Also provide an estimation for the following question: If you were to abandon your mod today, how long (in days/weeks/months/etc) do you think it will take for it to stop working on the latest experimental version?

When you contact me with the aforementioned details, you will also need to include the following comment inside your modinfo.json file:

```json 
"//compatibility": [ "tlg-experimental" ],
```

replace "tlg-experimental" with whatever fork(s) your mod supports. The following formats are supported:
`dda-stable`, `dda-experimental`, `tlg-experimental`, `bn-stable`, `bn-experimental`, `eod-experimental`, `tish-experimental`

Based on your description and estimate, a stability rating will be given to your mod inside my repo. Meaning that the mod will be supported on experimental versions until X amount of time passed, depending on the rating then it will cease to be available for download on the launcher until it's updated again. Note that this doesn't apply for stable game versions, as well as tish and eod. If your mod supports those and you confirm that they work, then it will be considered working. Please note that your mod might be removed if you provide false information

The stability ratings will be as follows:
- 0: supported until 1 month has passed since last release
- 1: supported until 3 months have passed since last release
- 2: supported until 6 months have passed since last release
- 3: 9 months
- 4: 1 year
- 5: 2 years
- 100: supported forever, your mod should never break unless the cataclysm happens irl or the devs rebuilt the engine from scratch
- -1: 1 week


## Tilesets:
[Work in Progress. What's stated here is a draft that is open for feedback. Feel free to make a request though!]

The only requirement for your tileset to be included, is to have at least 20% the number of assets MSX's tileset has, or [exact number to be inserted here] icons. or 10% if new stuff are being constantly added which is [exact number to be inserted here]. Or even 5% if new stuff are being constantly added AND you're willing to have your tileset marked as "Work in Progress".

If you meet any if these requirements, submit a request with the link to download your tileset. You will also need to provide a screenshot that showcases what your tileset looks like to be shown as a preview in the launcher!


## Soundpacks:
This one is simple. Just submit a request that has a link to download your soundpack's .zip file, I will look up your soundpack and what people are saying. As long as your soundpack is working, doesn't feel like it's missing too much for the user experience, and isn't doing some undisclosed shady stuff (eg undisclosed horror and jumpscares), it should become included.. speaking of which why isn't there a horror soundpack? If someone wants to make something like that, make sure to included something like "horror" in the soundpack's name
