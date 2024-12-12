(self: super: {
  myLinuxPackages = super.linuxPackagesFor (
    super.linux_latest.override {
      structuredExtraConfig = with super.lib.kernel; {
        VFIO_NOIOMMU = yes;
      };
    }
  );
})
