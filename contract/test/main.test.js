const { expect } = require("chai");

describe("CF", function () {
    it("deploy & create", async function () {
        const CF = await ethers.getContractFactory("Crowdfunding");
        const cf = await CF.deploy();

        await cf.createCampaign(
            1000,
            10000,
            "TEST",
            "T",
            { value: ethers.parseEther("0.1") }
        );

        const d = await cf.getDiscount();
        expect(d).to.be.gt(0);
    });
});